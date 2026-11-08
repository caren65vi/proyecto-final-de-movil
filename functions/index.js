const {setGlobalOptions} = require("firebase-functions");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {
  getFirestore,
  FieldValue,
  GeoPoint,
} = require("firebase-admin/firestore");
const crypto = require("crypto");

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
    const desde = aMinutos(b.inicio) - MINUTOS_ANTES;
    if (b.dia === dia && minutos >= desde && minutos <= aMinutos(b.fin)) {
      return b;
    }
  }
  return null;
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

// ---------------------------------------------------------------------
// abrirSesion: { grupoId, horas? } -> { sesionId, token }
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
  if (!abiertas.empty) {
    const sesion = abiertas.docs[0];
    const qr = await sesion.ref.collection("privado").doc("qr").get();
    return {sesionId: sesion.id, token: qr.get("token")};
  }

  const bloque = bloqueDeAhora(grupo.datos.horario);
  let horas;
  if (bloque) {
    horas = (aMinutos(bloque.fin) - aMinutos(bloque.inicio)) / 60;
  } else if (typeof datos.horas === "number" && datos.horas > 0) {
    horas = datos.horas; // clase de recuperación fuera del horario
  } else {
    throw new HttpsError(
        "failed-precondition",
        "Ahora no hay clase de este curso según el horario",
    );
  }

  const ref = sesiones.doc();
  const token = nuevoToken();
  const lote = db.batch();
  lote.set(ref, {
    grupoId: datos.grupoId,
    fecha: FieldValue.serverTimestamp(),
    inicio: bloque ? bloque.inicio : null,
    fin: bloque ? bloque.fin : null,
    horas,
    estado: "abierta",
    presentes: 0,
    ausentes: 0,
    justificadas: 0,
    abiertaPor: auth.uid,
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
  const horas = sesion.datos.horas;

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

  inscripciones.forEach((doc) => {
    let estado = estados[doc.id];
    if (!CAMPO_HORAS[estado]) {
      // No escaneó: queda ausente
      estado = "ausente";
      escritor.create(sesion.ref.collection("asistencias").doc(doc.id), {
        correo: doc.id,
        nombre: doc.get("nombre") || "",
        grupoId: datos.grupoId,
        sesionId: datos.sesionId,
        estado,
        horas,
        metodo: "automatico",
        registradaEn: FieldValue.serverTimestamp(),
      });
    }
    conteo[estado] += 1;
    escritor.update(doc.ref, {
      [CAMPO_HORAS[estado]]: FieldValue.increment(horas),
    });
  });

  escritor.update(sesion.ref, {
    estado: "cerrada",
    cerradaEn: FieldValue.serverTimestamp(),
    presentes: conteo.presente,
    ausentes: conteo.ausente,
    justificadas: conteo.justificada,
  });
  escritor.update(grupo.ref, {
    sesionesCerradas: FieldValue.increment(1),
    totalPresentes: FieldValue.increment(conteo.presente),
    totalAusentes: FieldValue.increment(conteo.ausente),
    totalJustificadas: FieldValue.increment(conteo.justificada),
  });
  await escritor.close();
  return conteo;
});

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
