import 'package:firebase_core/firebase_core.dart';

import '../../domain/entities/facultad.dart';
import '../../domain/entities/programa.dart';
import '../../domain/repositories/facultad_repository.dart';
import '../datasources/facultad_datasource.dart';

/// Implementa el contrato de Domain con Firestore.
class FacultadRepositoryImpl implements FacultadRepository {
  final FacultadDatasource datasource;

  FacultadRepositoryImpl(this.datasource);

  @override
  Stream<List<Facultad>> facultades() => datasource.facultades().handleError(
    (Object error) => throw _traducir(error),
  );

  @override
  Future<Facultad> crearFacultad({
    required String id,
    required String nombre,
    required String docenteUid,
  }) => _ejecutar(
    () => datasource.crearFacultad(
      id: id,
      nombre: nombre,
      docenteUid: docenteUid,
    ),
  );

  @override
  Future<void> eliminarFacultad(String id) =>
      _ejecutar(() => datasource.eliminarFacultad(id));

  @override
  Stream<List<Programa>> programas(String facultadId) => datasource
      .programas(facultadId)
      .handleError((Object error) => throw _traducir(error));

  @override
  Future<int> contarProgramas(String facultadId) =>
      _ejecutar(() => datasource.contarProgramas(facultadId));

  @override
  Future<Programa> crearPrograma({
    required String facultadId,
    required String id,
    required String nombre,
    required String docenteUid,
  }) => _ejecutar(
    () => datasource.crearPrograma(
      facultadId: facultadId,
      id: id,
      nombre: nombre,
      docenteUid: docenteUid,
    ),
  );

  @override
  Future<void> eliminarPrograma(String facultadId, String programaId) =>
      _ejecutar(() => datasource.eliminarPrograma(facultadId, programaId));

  @override
  Future<void> asignarProgramaEstudiante({
    required String uid,
    required Facultad facultad,
    required Programa programa,
  }) => _ejecutar(
    () => datasource.asignarProgramaEstudiante(
      uid: uid,
      facultad: facultad,
      programa: programa,
    ),
  );

  Future<T> _ejecutar<T>(Future<T> Function() accion) async {
    try {
      return await accion();
    } catch (error) {
      throw _traducir(error);
    }
  }

  // Convierte cualquier error en un FacultadError con mensaje en español
  FacultadError _traducir(Object error) {
    if (error is FacultadError) return error;
    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return const FacultadError(
          'No tienes permiso para realizar esta acción',
        );
      }
      return FacultadError('Error de conexión con Firebase (${error.code})');
    }
    return FacultadError('Ocurrió un error inesperado: $error');
  }
}
