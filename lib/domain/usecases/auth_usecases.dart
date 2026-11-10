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
    return repositorio.iniciarSesion(correo.trim().toLowerCase(), contrasena);
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
    // La cuenta queda creada pero no podrá entrar hasta verificar el correo
    // (la pantalla de verificación envía el código al abrirse)
    return repositorio.registrar(
      nombre: nombre.trim(),
      correo: correo.trim().toLowerCase(),
      contrasena: contrasena,
      rol: rol,
    );
  }
}

/// Envía el código al correo. Devuelve los segundos para poder pedir otro.
class EnviarCodigoVerificacion {
  final AuthRepository repositorio;
  EnviarCodigoVerificacion(this.repositorio);

  Future<int> call() => repositorio.enviarCodigoVerificacion();
}

class VerificarCodigo {
  final AuthRepository repositorio;
  VerificarCodigo(this.repositorio);

  Future<void> call(String codigo) async {
    final limpio = codigo.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(limpio)) {
      throw const AuthError('Escribe los 6 dígitos del código');
    }
    return repositorio.verificarCodigo(limpio);
  }
}

class ObtenerUsuarioActual {
  final AuthRepository repositorio;
  ObtenerUsuarioActual(this.repositorio);

  Future<Usuario?> call() => repositorio.obtenerUsuarioActual();
}

/// Al abrir la app: devuelve el usuario si ya tenía sesión abierta y su
/// correo está verificado. Si no, cierra la sesión y devuelve null.
class RestaurarSesion {
  final AuthRepository repositorio;
  RestaurarSesion(this.repositorio);

  Future<Usuario?> call() async {
    final usuario = await repositorio.obtenerUsuarioActual();
    if (usuario == null) return null;
    if (!await repositorio.correoVerificado()) {
      await repositorio.cerrarSesion();
      return null;
    }
    return usuario;
  }
}

class RecuperarContrasena {
  final AuthRepository repositorio;
  RecuperarContrasena(this.repositorio);

  Future<void> call(String correo) async {
    if (correo.trim().isEmpty) {
      throw const AuthError('Escribe tu correo');
    }
    return repositorio.recuperarContrasena(correo.trim().toLowerCase());
  }
}

class CerrarSesion {
  final AuthRepository repositorio;
  CerrarSesion(this.repositorio);

  Future<void> call() => repositorio.cerrarSesion();
}
