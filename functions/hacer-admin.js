// Script de UNA SOLA VEZ para crear el primer admin.
// Uso (dentro de la carpeta functions):
//   node hacer-admin.js tu-correo@gmail.com
// Necesita serviceAccountKey.json en esta carpeta. Bórralo al terminar.

const {initializeApp, cert} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");

initializeApp({credential: cert(require("./serviceAccountKey.json"))});

const email = process.argv[2];
if (!email) {
  console.error("Uso: node hacer-admin.js tu-correo@gmail.com");
  process.exit(1);
}

(async () => {
  const user = await getAuth().getUserByEmail(email);
  await getAuth().setCustomUserClaims(user.uid, {rol: "admin"});
  console.log(`${email} ahora es admin (uid: ${user.uid})`);
})().catch((err) => {
  console.error("Error:", err.message);
  process.exit(1);
});
