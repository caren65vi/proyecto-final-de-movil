import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/usuario.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_datasource.dart';

/// Implementa el contrato de Domain usando el datasource de Firebase.
class AuthRepositoryImpl implements AuthRepository {
  final AuthDatasource datasource;

  AuthRepositoryImpl(this.datasource);

  @override
  Future<Usuario> registrar({
    required String nombre,
    required String correo,
    required String contrasena,
    required String rol,
  }) {
    return _traducirErrores(() => datasource.registrar(
          nombre: nombre,
          correo: correo,
          contrasena: contrasena,
          rol: rol,
        ));
  }

  @override
  Future<Usuario> iniciarSesion(String correo, String contrasena) {
    return _traducirErrores(() async {
      final usuario = await datasource.iniciarSesion(correo, contrasena);
      if (usuario == null) {
        // Tiene cuenta en Authentication pero el docente lo eliminó de Firestore
        await datasource.cerrarSesion();
        throw const AuthError('Esta cuenta ya no está registrada en el sistema');
      }
      return usuario;
    });
  }

  @override
  Future<Usuario?> obtenerUsuarioActual() {
    return _traducirErrores(datasource.obtenerUsuarioActual);
  }

  @override
  Future<void> cerrarSesion() => datasource.cerrarSesion();

  // Convierte los errores de Firebase en mensajes en español
  Future<T> _traducirErrores<T>(Future<T> Function() accion) async {
    try {
      return await accion();
    } on FirebaseAuthException catch (e) {
      throw AuthError(_mensaje(e.code));
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw const AuthError('No tienes permiso para realizar esta acción');
      }
      throw AuthError('Error de conexión con Firebase (${e.code})');
    }
  }

  String _mensaje(String codigo) {
    switch (codigo) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Correo o contraseña incorrectos';
      case 'invalid-email':
        return 'El correo no es válido';
      case 'email-already-in-use':
        return 'Ese correo ya está registrado';
      case 'weak-password':
        return 'La contraseña debe tener al menos 6 caracteres';
      case 'too-many-requests':
        return 'Demasiados intentos, espera un momento';
      case 'network-request-failed':
        return 'Sin conexión a internet';
      default:
        return 'Error de autenticación ($codigo)';
    }
  }
}
