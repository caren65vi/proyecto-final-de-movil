import '../entities/usuario.dart';
import '../repositories/auth_repository.dart';

/// Casos de uso de autenticación: validan los datos y llaman al repositorio.

class IniciarSesion {
  final AuthRepository repositorio;
  IniciarSesion(this.repositorio);

  Future<Usuario> call(String correo, String contrasena) async {
    if (correo.trim().isEmpty || contrasena.isEmpty) {
      throw const AuthError('Escribe tu correo y tu contraseña');
    }
    return repositorio.iniciarSesion(correo.trim(), contrasena);
  }
}

class RegistrarUsuario {
  final AuthRepository repositorio;
  RegistrarUsuario(this.repositorio);

  Future<Usuario> call({
    required String nombre,
    required String correo,
    required String contrasena,
    required String rol,
  }) async {
    if (nombre.trim().isEmpty) {
      throw const AuthError('Escribe tu nombre');
    }
    if (correo.trim().isEmpty) {
      throw const AuthError('Escribe tu correo');
    }
    if (contrasena.length < 6) {
      throw const AuthError('La contraseña debe tener al menos 6 caracteres');
    }
    if (rol != 'docente' && rol != 'estudiante') {
      throw const AuthError('Selecciona si eres docente o estudiante');
    }
    return repositorio.registrar(
      nombre: nombre.trim(),
      correo: correo.trim(),
      contrasena: contrasena,
      rol: rol,
    );
  }
}

class ObtenerUsuarioActual {
  final AuthRepository repositorio;
  ObtenerUsuarioActual(this.repositorio);

  Future<Usuario?> call() => repositorio.obtenerUsuarioActual();
}

class CerrarSesion {
  final AuthRepository repositorio;
  CerrarSesion(this.repositorio);

  Future<void> call() => repositorio.cerrarSesion();
}
