const {setGlobalOptions, logger} = require("firebase-functions");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {
  getFirestore,
  FieldValue,
  GeoPoint,
  Timestamp,
} = require("firebase-admin/firestore");
const {defineSecret} = require("firebase-functions/params");
const crypto = require("crypto");
const nodemailer = require("nodemailer");

// Cuenta de Gmail que envía los códigos (se configuran con
// firebase functions:secrets:set GMAIL_USUARIO / GMAIL_CLAVE)
const GMAIL_USUARIO = defineSecret("GMAIL_USUARIO");
const GMAIL_CLAVE = defineSecret("GMAIL_CLAVE");

initializeApp();
const db = getFirestore();

// Limita las instancias para controlar costos
setGlobalOptions({maxInstances: 10});

const ROLES = ["admin", "docente", "estudiante"];

// Colombia no cambia de hora: siempre UTC-5
const DESFASE_COLOMBIA_MS = -5 * 60 * 60 * 1000;
// Metros extra por la imprecisión del GPS
const MARGEN_GPS = 30;
// Minutos antes del inicio en que ya se puede abrir la asistencia
const MINUTOS_ANTES = 15;

// Código de verificación del correo
const MINUTOS_CODIGO = 10; // vigencia
const MAX_INTENTOS = 5; // intentos fallidos antes de pedir otro
const SEGUNDOS_REENVIO = 60; // espera mínima entre envíos

// Campo que suma horas según el estado de la asistencia
const CAMPO_HORAS = {
  presente: "horasAsistidas",
  ausente: "horasFalta",
  justificada: "horasJustificadas",
};
const CAMPO_SESION = {
  presente: "presentes",
  ausente: "ausentes",
  justificada: "justificadas",
};
const CAMPO_GRUPO = {
  presente: "totalPresentes",
  ausente: "totalAusentes",
  justificada: "totalJustificadas",
};

/**
 * Asigna un rol (custom claim) a un usuario.
 * Solo la puede llamar un usuario que ya sea admin.
 * Recibe: { uid: string, rol: "admin" | "docente" | "estudiante" }
 */
exports.asignarRol = onCall(async (request) => {
  const token = request.auth && request.auth.token;
  if (!token || token.rol !== "admin") {
    throw new HttpsError(
        "permission-denied",
        "Solo un admin puede asignar roles",
    );
  }

  const {uid, rol} = request.data || {};
  if (typeof uid !== "string" || !uid) {
    throw new HttpsError("invalid-argument", "Falta el uid del usuario");
  }
  if (!ROLES.includes(rol)) {
    throw new HttpsError("invalid-argument", "Rol no válido");
  }

  await getAuth().setCustomUserClaims(uid, {rol});
  return {ok: true};
});

// ---------------------------------------------------------------------
// Funciones de ayuda
// ---------------------------------------------------------------------

/**
 * Exige que haya un usuario con sesión iniciada.
 * @param {object} request Petición de la función.
 * @return {object} request.auth
 */
function exigirSesion(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Inicia sesión primero");
  }
  return request.auth;
}

/**
 * Lee el grupo y comprueba que el usuario sea su docente.
 * @param {string} grupoId ID del grupo.
 * @param {string} uid UID del usuario.
 * @return {Promise<object>} {ref, datos}
 */
async function grupoDelDocente(grupoId, uid) {
  if (typeof grupoId !== "string" || !grupoId) {
    throw new HttpsError("invalid-argument", "Falta el curso");
  }
  const ref = db.collection("grupos").doc(grupoId);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "El curso no existe");
  }
  if (snap.get("docenteUid") !== uid) {
    throw new HttpsError("permission-denied", "No eres el docente del curso");
  }
  return {ref, datos: snap.data()};
}

/**
 * Lee una sesión y comprueba que siga abierta.
 * @param {object} grupoRef Referencia del grupo.
 * @param {string} sesionId ID de la sesión.
 * @return {Promise<object>} {ref, datos}
 */
async function sesionAbierta(grupoRef, sesionId) {
  if (typeof sesionId !== "string" || !sesionId) {
    throw new HttpsError("invalid-argument", "Falta la sesión");
  }
  const ref = grupoRef.collection("sesiones").doc(sesionId);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "La sesión no existe");
  }
  if (snap.get("estado") !== "abierta") {
    throw new HttpsError("failed-precondition", "La asistencia ya se cerró");
  }
  return {ref, datos: snap.data()};
}

/**
 * Convierte "08:30" en minutos desde la medianoche.
 * @param {string} hora Hora HH:MM.
 * @return {number} Minutos.
 */
function aMinutos(hora) {
  const partes = hora.split(":");
  return Number(partes[0]) * 60 + Number(partes[1]);
}

/**
 * Busca en el horario el bloque de clase de este momento.
 * @param {Array<object>} horario Lista de {dia, inicio, fin}.
 * @return {object|null} El bloque, o null si ahora no hay clase.
 */
function bloqueDeAhora(horario) {
  const ahora = new Date(Date.now() + DESFASE_COLOMBIA_MS);
  const diaJs = ahora.getUTCDay(); // 0 = domingo
  const dia = diaJs === 0 ? 7 : diaJs; // 1 = lunes ... 7 = domingo
  const minutos = ahora.getUTCHours() * 60 + ahora.getUTCMinutes();
  for (const b of horario || []) {
    if (b.dia === dia && enVentana(b, minutos)) return b;
  }
  return null;
}

/**
 * El minuto del día está entre MINUTOS_ANTES del inicio y el fin.
 * @param {object} clase {inicio, fin} en HH:MM.
 * @param {number} minutos Minutos desde la medianoche (hora de Colombia).
 * @return {boolean} true si se puede tomar asistencia.
 */
function enVentana(clase, minutos) {
  const desde = aMinutos(clase.inicio) - MINUTOS_ANTES;
  return minutos >= desde && minutos <= aMinutos(clase.fin);
}

/**
 * Fecha de Colombia ("AAAA-MM-DD") de un instante.
 * @param {number} ms Milisegundos desde 1970.
 * @return {string} Fecha.
 */
function diaColombia(ms) {
  return new Date(ms + DESFASE_COLOMBIA_MS).toISOString().slice(0, 10);
}

/**
 * Hoy está dentro del período del curso (de fechaInicio a fechaFin).
 * @param {object} grupo Datos del grupo.
 * @return {boolean} true si hoy hay clases del curso.
 */
function enPeriodo(grupo) {
  if (!grupo.fechaInicio || !grupo.fechaFin) return true;
  const hoy = diaColombia(Date.now());
  return (
    hoy >= diaColombia(grupo.fechaInicio.toMillis()) &&
    hoy <= diaColombia(grupo.fechaFin.toMillis())
  );
}

/**
 * Clase de este momento, solo si el curso está en su período: un bloque
 * del horario semanal o una clase de recuperación programada para hoy.
 * @param {object} grupoRef Referencia al grupo.
 * @param {object} grupo Datos del grupo.
 * @return {Promise<object|null>} {inicio, fin, recuperacionId?} o null.
 */
async function claseDeAhora(grupoRef, grupo) {
  if (!enPeriodo(grupo)) return null;
  const bloque = bloqueDeAhora(grupo.horario);
  if (bloque) return bloque;

  // Clase de recuperación de hoy (fecha "AAAA-MM-DD" en hora de Colombia)
  const ahora = new Date(Date.now() + DESFASE_COLOMBIA_MS);
  const minutos = ahora.getUTCHours() * 60 + ahora.getUTCMinutes();
  const recuperaciones = await grupoRef
      .collection("recuperaciones")
      .where("fecha", "==", diaColombia(Date.now()))
      .get();
  for (const doc of recuperaciones.docs) {
    const r = doc.data();
    if (enVentana(r, minutos)) {
      return {inicio: r.inicio, fin: r.fin, recuperacionId: doc.id};
    }
  }
  return null;
}

/**
 * La sesión es de la clase de ahora: se abrió hoy y en el mismo bloque.
 * @param {object} sesion Datos de la sesión.
 * @param {object|null} bloque Bloque de ahora (claseDeAhora).
 * @return {boolean} true si la sesión sigue vigente.
 */
function esSesionDeAhora(sesion, bloque) {
  if (!bloque || !sesion.fecha) return false;
  return (
    diaColombia(sesion.fecha.toMillis()) === diaColombia(Date.now()) &&
    sesion.inicio === bloque.inicio &&
    sesion.fin === bloque.fin
  );
}

/**
 * Distancia en metros entre dos coordenadas (fórmula de Haversine).
 * @param {number} lat1 Latitud 1.
 * @param {number} lon1 Longitud 1.
 * @param {number} lat2 Latitud 2.
 * @param {number} lon2 Longitud 2.
 * @return {number} Metros.
 */
function distanciaMetros(lat1, lon1, lat2, lon2) {
  const rad = (grados) => (grados * Math.PI) / 180;
  const dLat = rad(lat2 - lat1);
  const dLon = rad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(rad(lat1)) * Math.cos(rad(lat2)) * Math.sin(dLon / 2) ** 2;
  return 2 * 6371000 * Math.asin(Math.sqrt(a));
}

/**
 * Token aleatorio para el QR.
 * @return {string} 32 caracteres hexadecimales.
 */
function nuevoToken() {
  return crypto.randomBytes(16).toString("hex");
}

/**
 * Huella del código: en Firestore nunca se guarda el código en claro.
 * @param {string} uid UID del usuario.
 * @param {string} codigo Código de 6 dígitos.
 * @return {string} SHA-256 en hexadecimal.
 */
function huellaCodigo(uid, codigo) {
  return crypto.createHash("sha256").update(`${uid}:${codigo}`).digest("hex");
}

// ---------------------------------------------------------------------
// enviarCodigoVerificacion: {} -> { esperaSegundos }
// Genera un código de 6 dígitos y lo envía al correo del usuario.
// Si se pidió otro hace menos de un minuto no envía nada y responde
// cuántos segundos faltan (el código anterior sigue sirviendo).
// ---------------------------------------------------------------------
exports.enviarCodigoVerificacion = onCall(
    {secrets: [GMAIL_USUARIO, GMAIL_CLAVE]},
    async (request) => {
      const auth = exigirSesion(request);
      const usuario = await getAuth().getUser(auth.uid);
      if (usuario.emailVerified) {
        throw new HttpsError(
            "failed-precondition",
            "Tu correo ya está verificado. Inicia sesión.",
        );
      }
      if (!usuario.email) {
        throw new HttpsError(
            "failed-precondition",
            "La cuenta no tiene correo",
        );
      }

      const ref = db.collection("verificaciones").doc(auth.uid);
      const codigo = crypto.randomInt(0, 1000000).toString().padStart(6, "0");
      const ahora = Date.now();

      // La transacción evita que dos pedidos seguidos envíen dos correos
      const espera = await db.runTransaction(async (t) => {
        const snap = await t.get(ref);
        const enviadoEn = snap.exists ? snap.get("enviadoEn") : null;
        const pasados = enviadoEn ?
          (ahora - enviadoEn.toMillis()) / 1000 :
          null;
        if (pasados !== null && pasados < SEGUNDOS_REENVIO) {
          return Math.ceil(SEGUNDOS_REENVIO - pasados);
        }
        t.set(ref, {
          huella: huellaCodigo(auth.uid, codigo),
          intentos: 0,
          enviadoEn: Timestamp.fromMillis(ahora),
          expiraEn: Timestamp.fromMillis(ahora + MINUTOS_CODIGO * 60 * 1000),
        });
        return 0;
      });
      if (espera > 0) return {esperaSegundos: espera};

      try {
        const correo = nodemailer.createTransport({
          service: "gmail",
          auth: {user: GMAIL_USUARIO.value(), pass: GMAIL_CLAVE.value()},
        });
        await correo.sendMail({
          from: `"Ceiba" <${GMAIL_USUARIO.value()}>`,
          to: usuario.email,
          subject: `Tu código de verificación de Ceiba: ${codigo}`,
          text:
            `Tu código de verificación es ${codigo}.\n` +
            `Vence en ${MINUTOS_CODIGO} minutos.\n\n` +
            "Si no creaste una cuenta en Ceiba, ignora este correo.",
          html:
            "<div style=\"font-family:Arial,sans-serif;color:#191c1b\">" +
            "<h2 style=\"color:#134e3f\">Verifica tu correo</h2>" +
            "<p>Escribe este código en la app Ceiba:</p>" +
            "<p style=\"font-size:32px;font-weight:bold;letter-spacing:8px;" +
            `color:#00362a">${codigo}</p>` +
            `<p>Vence en ${MINUTOS_CODIGO} minutos.</p>` +
            "<p style=\"color:#707973;font-size:12px\">Si no creaste una " +
            "cuenta en Ceiba, ignora este correo.</p></div>",
        });
      } catch (error) {
        logger.error("enviarCodigoVerificacion: no se pudo enviar", {
          uid: auth.uid,
          error: error.message,
        });
        // Se borra para que pueda pedir otro sin esperar
        await ref.delete();
        throw new HttpsError(
            "unavailable",
            "No se pudo enviar el correo. Intenta de nuevo en un momento.",
        );
      }
      return {esperaSegundos: SEGUNDOS_REENVIO};
    },
);

// ---------------------------------------------------------------------
// verificarCodigo: { codigo } -> { ok }
// Si el código es correcto marca el correo como verificado en Auth.
// ---------------------------------------------------------------------
exports.verificarCodigo = onCall(async (request) => {
  const auth = exigirSesion(request);
  const codigo = request.data && request.data.codigo;
  if (typeof codigo !== "string" || !/^\d{6}$/.test(codigo)) {
    throw new HttpsError("invalid-argument", "El código debe tener 6 dígitos");
  }

  const ref = db.collection("verificaciones").doc(auth.uid);
  // Devuelve el resultado en vez de lanzar el error dentro de la
  // transacción, para que el intento fallido sí quede guardado
  const resultado = await db.runTransaction(async (t) => {
    const snap = await t.get(ref);
    if (!snap.exists) return {estado: "sin-codigo"};
    if (snap.get("expiraEn").toMillis() < Date.now()) {
      return {estado: "vencido"};
    }
    const intentos = snap.get("intentos") || 0;
    if (intentos >= MAX_INTENTOS) return {estado: "bloqueado"};

    const esperada = Buffer.from(snap.get("huella"), "hex");
    const recibida = Buffer.from(huellaCodigo(auth.uid, codigo), "hex");
    if (!crypto.timingSafeEqual(esperada, recibida)) {
      t.update(ref, {intentos: intentos + 1});
      return {estado: "incorrecto", quedan: MAX_INTENTOS - intentos - 1};
    }
    t.delete(ref);
    return {estado: "ok"};
  });

  switch (resultado.estado) {
    case "sin-codigo":
      throw new HttpsError(
          "failed-precondition",
          "No hay un código activo. Pide uno nuevo.",
      );
    case "vencido":
      throw new HttpsError(
          "deadline-exceeded",
          "El código venció. Pide uno nuevo.",
      );
    case "bloqueado":
      throw new HttpsError(
          "resource-exhausted",
          "Demasiados intentos. Pide un código nuevo.",
      );
    case "incorrecto":
      throw new HttpsError(
          "invalid-argument",
          resultado.quedan > 0 ?
            `Código incorrecto. Te quedan ${resultado.quedan} intentos.` :
            "Código incorrecto. Pide un código nuevo.",
      );
  }

  await getAuth().updateUser(auth.uid, {emailVerified: true});
  return {ok: true};
});

// ---------------------------------------------------------------------
// abrirSesion: { grupoId } -> { sesionId, token }
// ---------------------------------------------------------------------
exports.abrirSesion = onCall(async (request) => {
  const auth = exigirSesion(request);
  const datos = request.data || {};
  const grupo = await grupoDelDocente(datos.grupoId, auth.uid);
  const sesiones = grupo.ref.collection("sesiones");

  // Si ya hay una abierta (el docente salió y volvió) se reutiliza
  const abiertas = await sesiones
      .where("estado", "==", "abierta")
      .limit(1)
      .get();
  const bloque = await claseDeAhora(grupo.ref, grupo.datos);
  if (!abiertas.empty) {
    const sesion = abiertas.docs[0];
    if (esSesionDeAhora(sesion.data(), bloque)) {
      const qr = await sesion.ref.collection("privado").doc("qr").get();
      return {sesionId: sesion.id, token: qr.get("token")};
    }
    // Quedó abierta de una clase anterior: se cierra (los que no
    // escanearon quedan ausentes) y no se vuelve a usar
    await finalizarSesion(
        grupo,
        {ref: sesion.ref, datos: sesion.data()},
        {grupoId: datos.grupoId, sesionId: sesion.id},
    );
  }

  // Solo se toma asistencia el día y la hora de la clase
  if (!enPeriodo(grupo.datos)) {
    throw new HttpsError(
        "failed-precondition",
        "El curso no está dentro de su período de clases",
    );
  }
  if (!bloque) {
    throw new HttpsError(
        "failed-precondition",
        "Ahora no hay clase de este curso según el horario",
    );
  }
  const horas = (aMinutos(bloque.fin) - aMinutos(bloque.inicio)) / 60;

  const ref = sesiones.doc();
  const token = nuevoToken();
  const lote = db.batch();
  lote.set(ref, {
    grupoId: datos.grupoId,
    fecha: FieldValue.serverTimestamp(),
    inicio: bloque.inicio,
    fin: bloque.fin,
    horas,
    estado: "abierta",
    presentes: 0,
    ausentes: 0,
    justificadas: 0,
    abiertaPor: auth.uid,
    // Si es una clase de recuperación, cuál (null = horario normal)
    recuperacionId: bloque.recuperacionId || null,
  });
  lote.set(ref.collection("privado").doc("qr"), {
    token,
    anterior: null,
    actualizadoEn: FieldValue.serverTimestamp(),
  });
  await lote.commit();
  return {sesionId: ref.id, token};
});

// ---------------------------------------------------------------------
// renovarQR: { grupoId, sesionId } -> { token }
// ---------------------------------------------------------------------
exports.renovarQR = onCall(async (request) => {
  const auth = exigirSesion(request);
  const datos = request.data || {};
  const grupo = await grupoDelDocente(datos.grupoId, auth.uid);
  const sesion = await sesionAbierta(grupo.ref, datos.sesionId);

  const qrRef = sesion.ref.collection("privado").doc("qr");
  const token = nuevoToken();
  await qrRef.set({
    token,
    anterior: null,
    actualizadoEn: FieldValue.serverTimestamp(),
  });
  return {token};
});

// ---------------------------------------------------------------------
// registrarAsistenciaQR:
// { grupoId, sesionId, token, latitud, longitud } -> { ok }
// ---------------------------------------------------------------------
exports.registrarAsistenciaQR = onCall(async (request) => {
  const auth = exigirSesion(request);
  if (auth.token.email_verified !== true || !auth.token.email) {
    throw new HttpsError("permission-denied", "Verifica tu correo primero");
  }
  const correo = auth.token.email.toLowerCase();
  const datos = request.data || {};
  if (
    typeof datos.grupoId !== "string" ||
    !datos.grupoId ||
    typeof datos.latitud !== "number" ||
    !Number.isFinite(datos.latitud) ||
    datos.latitud < -90 ||
    datos.latitud > 90 ||
    typeof datos.longitud !== "number" ||
    !Number.isFinite(datos.longitud) ||
    datos.longitud < -180 ||
    datos.longitud > 180
  ) {
    throw new HttpsError("invalid-argument", "Datos incompletos");
  }

  // 1. El curso existe y el estudiante está inscrito
  const grupoRef = db.collection("grupos").doc(datos.grupoId);
  const [grupoSnap, inscripcion] = await Promise.all([
    grupoRef.get(),
    grupoRef.collection("inscripciones").doc(correo).get(),
  ]);
  if (!grupoSnap.exists) {
    throw new HttpsError("not-found", "El curso no existe");
  }
  if (!inscripcion.exists) {
    throw new HttpsError(
        "permission-denied",
        "No estás inscrito en este curso",
    );
  }

  // 2. La sesión sigue abierta
  const sesion = await sesionAbierta(grupoRef, datos.sesionId);
  const claseActual = await claseDeAhora(grupoRef, grupoSnap.data());
  if (!esSesionDeAhora(sesion.datos, claseActual)) {
    throw new HttpsError(
        "failed-precondition",
        "La clase de esta asistencia ya terminó",
    );
  }
  if (typeof datos.token !== "string" || !datos.token) {
    throw new HttpsError("invalid-argument", "Falta el código QR");
  }

  // 3. El estudiante está cerca del salón
  const salon = grupoSnap.get("ubicacion");
  if (
    !salon ||
    typeof salon.latitude !== "number" ||
    typeof salon.longitude !== "number"
  ) {
    throw new HttpsError(
        "failed-precondition",
        "El curso no tiene una ubicación válida",
    );
  }
  const distancia = distanciaMetros(
      datos.latitud,
      datos.longitud,
      salon.latitude,
      salon.longitude,
  );
  if (distancia > grupoSnap.get("radioMetros") + MARGEN_GPS) {
    throw new HttpsError(
        "failed-precondition",
        `Estás a ${Math.round(distancia)} m del salón, acércate más`,
    );
  }

  // 4. Se guarda una sola vez (transacción)
  const asistenciaRef = sesion.ref.collection("asistencias").doc(correo);
  const qrRef = sesion.ref.collection("privado").doc("qr");
  await db.runTransaction(async (t) => {
    const [sesionActual, qrActual, existente] = await Promise.all([
      t.get(sesion.ref),
      t.get(qrRef),
      t.get(asistenciaRef),
    ]);
    if (!sesionActual.exists || sesionActual.get("estado") !== "abierta") {
      throw new HttpsError("failed-precondition", "La asistencia ya se cerró");
    }
    if (existente.exists) {
      throw new HttpsError("already-exists", "Ya registraste tu asistencia");
    }
    if (!qrActual.exists || qrActual.get("token") !== datos.token) {
      throw new HttpsError(
          "failed-precondition",
          "El código QR ya fue usado; escanea el código actualizado",
      );
    }

    const tokenSiguiente = nuevoToken();
    t.create(asistenciaRef, {
      correo,
      nombre: inscripcion.get("nombre") || "",
      grupoId: datos.grupoId,
      sesionId: datos.sesionId,
      estado: "presente",
      horas: sesion.datos.horas,
      metodo: "qr",
      registradaEn: FieldValue.serverTimestamp(),
      ubicacion: new GeoPoint(datos.latitud, datos.longitud),
    });
    t.update(sesion.ref, {
      presentes: FieldValue.increment(1),
    });
    t.update(qrRef, {
      token: tokenSiguiente,
      anterior: null,
      actualizadoEn: FieldValue.serverTimestamp(),
    });
  });
  return {ok: true};
});

// ---------------------------------------------------------------------
// cerrarSesion: { grupoId, sesionId } -> { presente, ausente, justificada }
// ---------------------------------------------------------------------
exports.cerrarSesion = onCall(async (request) => {
  const auth = exigirSesion(request);
  const datos = request.data || {};
  const grupo = await grupoDelDocente(datos.grupoId, auth.uid);
  const sesion = await sesionAbierta(grupo.ref, datos.sesionId);
  return finalizarSesion(grupo, sesion, datos);
});

/**
 * Cierra una sesión: marca ausentes a quienes no escanearon y suma
 * las horas y los totales. La usan cerrarSesion y abrirSesion (para
 * cerrar una sesión que quedó abierta de una clase anterior).
 * @param {object} grupo {ref, datos} del grupo.
 * @param {object} sesion {ref, datos} de la sesión abierta.
 * @param {object} datos {grupoId, sesionId}.
 * @return {Promise<object>} Conteo {presente, ausente, justificada}.
 */
async function finalizarSesion(grupo, sesion, datos) {
  // 1. Primero se cierra la sesión (transacción). registrarAsistenciaQR
  // también lee la sesión en su transacción, así que después de esto
  // ningún estudiante puede registrarse y las cuentas no cambian.
  const horas = await db.runTransaction(async (t) => {
    const actual = await t.get(sesion.ref);
    if (!actual.exists || actual.get("estado") !== "abierta") {
      throw new HttpsError("failed-precondition", "La asistencia ya se cerró");
    }
    t.update(sesion.ref, {
      estado: "cerrada",
      cerradaEn: FieldValue.serverTimestamp(),
    });
    return actual.get("horas");
  });

  // 2. Con la sesión ya cerrada se leen las asistencias definitivas
  const [inscripciones, asistencias] = await Promise.all([
    grupo.ref.collection("inscripciones").get(),
    sesion.ref.collection("asistencias").get(),
  ]);
  const estados = {};
  asistencias.forEach((doc) => {
    estados[doc.id] = doc.get("estado");
  });

  const conteo = {presente: 0, ausente: 0, justificada: 0};
  const escritor = db.bulkWriter(); // agrupa muchas escrituras

  // bulkWriter no lanza error si falla una escritura: se anotan aquí
  const fallas = [];
  const pendientes = [];
  const vigilar = (escritura, ruta) => {
    pendientes.push(
        escritura.catch((error) => fallas.push({ruta, error: error.message})),
    );
  };

  inscripciones.forEach((doc) => {
    let estado = estados[doc.id];
    if (!CAMPO_HORAS[estado]) {
      // No escaneó: queda ausente
      estado = "ausente";
      const ref = sesion.ref.collection("asistencias").doc(doc.id);
      vigilar(escritor.set(ref, {
        correo: doc.id,
        nombre: doc.get("nombre") || "",
        grupoId: datos.grupoId,
        sesionId: datos.sesionId,
        estado,
        horas,
        metodo: "automatico",
        registradaEn: FieldValue.serverTimestamp(),
      }), ref.path);
    }
    conteo[estado] += 1;
    vigilar(escritor.update(doc.ref, {
      [CAMPO_HORAS[estado]]: FieldValue.increment(horas),
    }), doc.ref.path);
  });

  // 3. Totales de la sesión y del curso
  vigilar(escritor.update(sesion.ref, {
    presentes: conteo.presente,
    ausentes: conteo.ausente,
    justificadas: conteo.justificada,
  }), sesion.ref.path);
  vigilar(escritor.update(grupo.ref, {
    sesionesCerradas: FieldValue.increment(1),
    totalPresentes: FieldValue.increment(conteo.presente),
    totalAusentes: FieldValue.increment(conteo.ausente),
    totalJustificadas: FieldValue.increment(conteo.justificada),
  }), grupo.ref.path);
  await escritor.close();
  await Promise.all(pendientes);

  if (fallas.length > 0) {
    logger.error("cerrarSesion: escrituras fallidas", {
      grupoId: datos.grupoId,
      sesionId: datos.sesionId,
      fallas,
    });
    throw new HttpsError(
        "internal",
        "La sesión se cerró, pero algunos registros no se guardaron",
    );
  }
  return conteo;
}

// ---------------------------------------------------------------------
// corregirAsistencia: se ejecuta sola cuando el docente cambia el estado
// de una asistencia de una sesión ya cerrada (ej. ausente -> justificada)
// ---------------------------------------------------------------------
exports.corregirAsistencia = onDocumentUpdated(
    "grupos/{grupoId}/sesiones/{sesionId}/asistencias/{correo}",
    async (event) => {
      const antes = event.data.before.data();
      const despues = event.data.after.data();
      if (antes.estado === despues.estado) return;
      if (!CAMPO_HORAS[antes.estado] || !CAMPO_HORAS[despues.estado]) return;

      const {grupoId, sesionId, correo} = event.params;
      const grupoRef = db.collection("grupos").doc(grupoId);
      const sesionRef = grupoRef.collection("sesiones").doc(sesionId);
      const sesion = await sesionRef.get();
      // Si sigue abierta, cerrarSesion hará las cuentas
      if (sesion.get("estado") !== "cerrada") return;

      const horas = sesion.get("horas");
      const lote = db.batch();
      lote.update(grupoRef.collection("inscripciones").doc(correo), {
        [CAMPO_HORAS[antes.estado]]: FieldValue.increment(-horas),
        [CAMPO_HORAS[despues.estado]]: FieldValue.increment(horas),
      });
      lote.update(sesionRef, {
        [CAMPO_SESION[antes.estado]]: FieldValue.increment(-1),
        [CAMPO_SESION[despues.estado]]: FieldValue.increment(1),
      });
      lote.update(grupoRef, {
        [CAMPO_GRUPO[antes.estado]]: FieldValue.increment(-1),
        [CAMPO_GRUPO[despues.estado]]: FieldValue.increment(1),
      });
      await lote.commit();
    },
);
