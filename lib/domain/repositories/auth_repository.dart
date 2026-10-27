import '../entities/usuario.dart';

/// Error con un mensaje listo para mostrar al usuario.
class AuthError implements Exception {
  final String mensaje;
  const AuthError(this.mensaje);

  @override
  String toString() => mensaje;
}

/// La contraseña es correcta pero el usuario no ha abierto el enlace de verificación.
/// La sesión queda abierta para poder reenviar el correo.
class CorreoNoVerificadoError extends AuthError {
  const CorreoNoVerificadoError()
      : super('Debes verificar tu correo antes de iniciar sesión');
}

/// Contrato: qué operaciones de autenticación existen (no dice cómo se hacen).
abstract class AuthRepository {
  Future<Usuario> registrar({
    required String nombre,
    required String correo,
    required String contrasena,
    required String rol,
  });

  Future<Usuario> iniciarSesion(String correo, String contrasena);

  Future<void> recuperarContrasena(String correo);

  Future<void> enviarCorreoVerificacion();

  Future<bool> correoVerificado();

  Future<Usuario?> obtenerUsuarioActual();

  Future<void> cerrarSesion();
}
