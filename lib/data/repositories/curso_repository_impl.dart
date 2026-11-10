import 'package:firebase_core/firebase_core.dart';

import '../../domain/entities/curso.dart';
import '../../domain/entities/estudiante_inscrito.dart';
import '../../domain/entities/recuperacion.dart';
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

  // Convierte cualquier error en un CursoError con mensaje en español
  CursoError _traducir(Object error) {
    if (error is CursoError) return error;
    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return const CursoError('No tienes permiso para realizar esta acción');
      }
      return CursoError('Error de conexión con Firebase (${error.code})');
    }
    return CursoError('Ocurrió un error inesperado: $error');
  }

  @override
  Stream<Curso> curso(String grupoId) => cursoDatasource
      .curso(grupoId)
      .handleError((Object error) => throw _traducir(error));

  @override
  Stream<List<EstudianteInscrito>> estudiantes(String grupoId) =>
      cursoDatasource
          .estudiantes(grupoId)
          .handleError((Object error) => throw _traducir(error));

  Future<T> _ejecutar<T>(Future<T> Function() accion) async {
    try {
      return await accion();
    } catch (error) {
      throw _traducir(error);
    }
  }

  @override
  Future<void> editarCurso(Curso curso) =>
      _ejecutar(() => cursoDatasource.editarCurso(curso));

  @override
  Future<void> agregarEstudiante(
    String grupoId,
    EstudianteInscrito estudiante,
  ) => _ejecutar(() => cursoDatasource.agregarEstudiante(grupoId, estudiante));

  @override
  Stream<List<Recuperacion>> recuperaciones(String grupoId) => cursoDatasource
      .recuperaciones(grupoId)
      .handleError((Object error) => throw _traducir(error));

  @override
  Future<void> programarRecuperacion(
    String grupoId,
    Recuperacion recuperacion,
    String docenteUid,
  ) => _ejecutar(
    () => cursoDatasource.programarRecuperacion(
      grupoId,
      recuperacion,
      docenteUid,
    ),
  );

  @override
  Future<void> eliminarRecuperacion(String grupoId, String recuperacionId) =>
      _ejecutar(
        () => cursoDatasource.eliminarRecuperacion(grupoId, recuperacionId),
      );

  @override
  Future<void> quitarEstudiante(String grupoId, String correo) =>
      _ejecutar(() => cursoDatasource.quitarEstudiante(grupoId, correo));
}
