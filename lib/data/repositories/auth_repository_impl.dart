import 'package:cloud_functions/cloud_functions.dart';
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
    return _traducirErrores(() async {
      try {
        return await datasource.registrar(
          nombre: nombre,
          correo: correo,
          contrasena: contrasena,
          rol: rol,
        );
      } on FirebaseException catch (e) {
        // Las reglas rechazan el rol docente si el correo no está autorizado
        if (e.code == 'permission-denied' && rol == 'docente') {
          throw const AuthError(
            'Tu correo no está autorizado como docente. Pide que lo agreguen.',
          );
        }
        rethrow;
      }
    });
  }

  @override
  Future<Usuario> iniciarSesion(String correo, String contrasena) {
    return _traducirErrores(() async {
      final usuario = await datasource.iniciarSesion(correo, contrasena);
      if (usuario == null) {
        // Tiene cuenta en Authentication pero el docente lo eliminó de Firestore
        await datasource.cerrarSesion();
        throw const AuthError(
          'Esta cuenta ya no está registrada en el sistema',
        );
      }
      if (!await datasource.correoVerificado()) {
        throw const CorreoNoVerificadoError();
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
    } on FirebaseFunctionsException catch (e) {
      // Las funciones ya responden con mensajes en español; los errores
      // internos llegan solo con el código en mayúsculas ("INTERNAL")
      final mensaje = e.message;
      if (mensaje == null || mensaje == mensaje.toUpperCase()) {
        throw AuthError('Error de conexión con el servidor (${e.code})');
      }
      throw AuthError(mensaje);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw const AuthError('No tienes permiso para realizar esta acción');
      }
      throw AuthError('Error de conexión con Firebase (${e.code})');
    }
  }

  @override
  Future<void> recuperarContrasena(String correo) {
    return _traducirErrores(() => datasource.enviarCorreoRecuperacion(correo));
  }

  @override
  Future<int> enviarCodigoVerificacion() {
    return _traducirErrores(datasource.enviarCodigoVerificacion);
  }

  @override
  Future<void> verificarCodigo(String codigo) {
    return _traducirErrores(() => datasource.verificarCodigo(codigo));
  }

  @override
  Future<bool> correoVerificado() {
    return _traducirErrores(datasource.correoVerificado);
  }

  String _mensaje(String codigo) {
    switch (codigo) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Correo o contraseña incorrectos';
      case 'invalid-email':
      case 'missing-email':
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
