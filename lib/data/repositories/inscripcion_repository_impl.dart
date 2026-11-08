import 'package:firebase_core/firebase_core.dart';

import '../../domain/entities/materia_estudiante.dart';
import '../../domain/repositories/curso_repository.dart';
import '../../domain/repositories/inscripcion_repository.dart';
import '../datasources/inscripcion_datasource.dart';

/// Implementa el contrato de Domain usando el datasource de inscripciones.
class InscripcionRepositoryImpl implements InscripcionRepository {
  final InscripcionDatasource datasource;

  InscripcionRepositoryImpl(this.datasource);

  // Convierte cualquier error en un CursoError con mensaje en español
  CursoError _traducir(Object error) {
    if (error is CursoError) return error;
    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return const CursoError('No tienes permiso para ver tus materias');
      }
      if (error.code == 'failed-precondition') {
        return const CursoError(
          'Falta crear el índice de "inscripciones" en Firestore',
        );
      }
      return CursoError('Error de conexión con Firebase (${error.code})');
    }
    return CursoError('Ocurrió un error inesperado: $error');
  }

  @override
  Stream<List<MateriaEstudiante>> misMaterias(String correo) => datasource
      .misMaterias(correo)
      .handleError((Object error) => throw _traducir(error));

  @override
  Future<void> enlazarCuenta(String correo, String uid) async {
    try {
      await datasource.enlazarCuenta(correo, uid);
    } catch (error) {
      throw _traducir(error);
    }
  }
}
