import 'package:firebase_core/firebase_core.dart';

import '../../domain/entities/curso.dart';
import '../../domain/entities/estudiante_inscrito.dart';
import '../../domain/repositories/curso_repository.dart';
import '../datasources/curso_datasource.dart';
import '../datasources/lista_estudiantes_datasource.dart';
import '../datasources/ubicacion_datasource.dart';

/// Implementa el contrato de Domain uniendo los tres datasources.
class CursoRepositoryImpl implements CursoRepository {
  final CursoDatasource cursoDatasource;
  final UbicacionDatasource ubicacionDatasource;
  final ListaEstudiantesDatasource listaDatasource;

  CursoRepositoryImpl({
    required this.cursoDatasource,
    required this.ubicacionDatasource,
    required this.listaDatasource,
  });

  @override
  Future<String> crearCurso(
    Curso curso,
    List<EstudianteInscrito> estudiantes,
  ) async {
    try {
      return await cursoDatasource.crearCurso(curso, estudiantes);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw const CursoError('No tienes permiso para crear este curso');
      }
      throw CursoError('Error de conexión con Firebase (${e.code})');
    }
  }

  @override
  Stream<List<Curso>> misCursos(String docenteUid) {
    return cursoDatasource.misCursos(docenteUid).handleError((Object e) {
      if (e is FirebaseException && e.code == 'permission-denied') {
        throw const CursoError('No tienes permiso para ver estos cursos');
      }
      if (e is FirebaseException) {
        throw CursoError('Error de conexión con Firebase (${e.code})');
      }
      throw e;
    });
  }

  @override
  Future<({double latitud, double longitud})> obtenerUbicacionActual() =>
      ubicacionDatasource.obtenerUbicacionActual();

  @override
  Future<({String nombreArchivo, List<EstudianteInscrito> estudiantes})?>
  importarEstudiantes() => listaDatasource.importarEstudiantes();
}
