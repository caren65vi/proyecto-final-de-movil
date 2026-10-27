import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/usuario_model.dart';

/// Habla directamente con Firebase Authentication y Cloud Firestore.
class AuthDatasource {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usuarios =>
      _db.collection('usuarios');

  // Crea la cuenta en Authentication y guarda sus datos en Firestore
  Future<UsuarioModel> registrar({
    required String nombre,
    required String correo,
    required String contrasena,
    required String rol,
  }) async {
    final credencial = await _auth.createUserWithEmailAndPassword(
      email: correo,
      password: contrasena,
    );
    final usuario = UsuarioModel(
      uid: credencial.user!.uid,
      nombre: nombre,
      correo: correo,
      rol: rol,
      fechaCreacion: DateTime.now(),
    );
    // El ID del documento es el UID del usuario
    await _usuarios.doc(usuario.uid).set(usuario.toMap());
    return usuario;
  }

  // Valida correo y contraseña y lee el rol desde Firestore
  Future<UsuarioModel?> iniciarSesion(String correo, String contrasena) async {
    final credencial = await _auth.signInWithEmailAndPassword(
      email: correo,
      password: contrasena,
    );
    return obtenerUsuario(credencial.user!.uid);
  }

  // Usuario con sesión abierta (null si no hay sesión)
  Future<UsuarioModel?> obtenerUsuarioActual() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return obtenerUsuario(user.uid);
  }

  // Lee el documento usuarios/{uid}; null si no existe
  Future<UsuarioModel?> obtenerUsuario(String uid) async {
    final doc = await _usuarios.doc(uid).get();
    if (!doc.exists) return null;
    return UsuarioModel.fromFirestore(doc);
  }

//firebase envia un correo de recuperación de contraseña al correo del usuario
  Future<void> enviarCorreoRecuperacion(String correo) async {
    await _auth.setLanguageCode('es'); // el correo llega en español
    await _auth.sendPasswordResetEmail(email: correo);
  }

  // Firebase envía un enlace de verificación al correo del usuario con sesión abierta
  Future<void> enviarCorreoVerificacion() async {
    await _auth.setLanguageCode('es'); // el correo llega en español
    await _auth.currentUser!.sendEmailVerification();
  }

  // Recarga el usuario desde Firebase para saber si ya abrió el enlace
  Future<bool> correoVerificado() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    return _auth.currentUser!.emailVerified;
  }

  Future<void> cerrarSesion() => _auth.signOut();
}
