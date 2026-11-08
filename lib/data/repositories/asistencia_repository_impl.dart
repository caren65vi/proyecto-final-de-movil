import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../domain/entities/asistencia.dart';
import '../../domain/repositories/asistencia_repository.dart';
import '../../domain/repositories/curso_repository.dart';
import '../datasources/asistencia_datasource.dart';
import '../datasources/ubicacion_datasource.dart';

/// Implementa el contrato usando las Functions y el GPS.
class AsistenciaRepositoryImpl implements AsistenciaRepository {
  final AsistenciaDatasource datasource;
  final UbicacionDatasource ubicacionDatasource;

  AsistenciaRepositoryImpl({
    required this.datasource,
    required this.ubicacionDatasource,
  });

  @override
  Future<({String sesionId, String token})> abrirSesion(String grupoId) =>
      _ejecutar(() => datasource.abrirSesion(grupoId));

  @override
  Future<String> renovarQR(String grupoId, String sesionId) =>
      _ejecutar(() => datasource.renovarQR(grupoId, sesionId));

  @override
  Future<void> cerrarSesion(String grupoId, String sesionId) =>
      _ejecutar(() => datasource.cerrarSesion(grupoId, sesionId));

  // Primero lee el GPS y luego envía todo a la función
  @override
  Future<void> registrarAsistencia({
    required String grupoId,
    required String sesionId,
    required String token,
  }) => _ejecutar(() async {
    final posicion = await ubicacionDatasource.obtenerUbicacionActual();
    await datasource.registrarAsistencia(
      grupoId: grupoId,
      sesionId: sesionId,
      token: token,
      latitud: posicion.latitud,
      longitud: posicion.longitud,
    );
  });

  @override
  Stream<List<Asistencia>> asistencias(String grupoId, String sesionId) =>
      datasource
          .asistencias(grupoId, sesionId)
          .handleError((Object error) => throw _traducir(error));

  @override
  Stream<String> tokenQR(String grupoId, String sesionId) => datasource
      .tokenQR(grupoId, sesionId)
      .handleError((Object error) => throw _traducir(error));

  Future<T> _ejecutar<T>(Future<T> Function() accion) async {
    try {
      return await accion();
    } catch (error) {
      throw _traducir(error);
    }
  }

  // Los mensajes de las Functions ya vienen en español
  AsistenciaError _traducir(Object error) {
    if (error is AsistenciaError) return error;
    if (error is CursoError) return AsistenciaError(error.mensaje); // GPS
    if (error is FirebaseFunctionsException) {
      return AsistenciaError(
        error.message ?? 'Error del servidor (${error.code})',
      );
    }
    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return const AsistenciaError('No tienes permiso para ver esto');
      }
      return AsistenciaError('Error de conexión con Firebase (${error.code})');
    }
    return AsistenciaError('Ocurrió un error inesperado: $error');
  }
}
