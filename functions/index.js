const {setGlobalOptions} = require("firebase-functions");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");

initializeApp();

// Limita las instancias para controlar costos
setGlobalOptions({maxInstances: 10});

const ROLES = ["admin", "docente", "estudiante"];

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
