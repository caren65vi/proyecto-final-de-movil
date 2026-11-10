import '../entities/curso.dart';
import '../entities/estudiante_inscrito.dart';
import '../entities/recuperacion.dart';
import '../entities/resultado_importacion.dart';

/// Error con un mensaje listo para mostrar al docente.
class CursoError implements Exception {
  final String mensaje;
  const CursoError(this.mensaje);

  @override
  String toString() => mensaje;
}

/// Contrato: qué operaciones de cursos existen (no dice cómo se hacen).
abstract class CursoRepository {
  /// Guarda el curso y su lista de estudiantes; devuelve el ID del curso.
  Future<String> crearCurso(Curso curso, List<EstudianteInscrito> estudiantes);

  /// Cursos del docente; emite una lista nueva cada vez que cambian.
  Stream<List<Curso>> misCursos(String docenteUid);

  /// Un curso por su ID, en tiempo real.
  Stream<Curso> curso(String grupoId);

  /// Estudiantes inscritos en el curso, en tiempo real.
  Stream<List<EstudianteInscrito>> estudiantes(String grupoId);

  /// Guarda los cambios de un curso que ya existe.
  Future<void> editarCurso(Curso curso);

  /// Agrega un estudiante a la lista de clase.
  Future<void> agregarEstudiante(String grupoId, EstudianteInscrito estudiante);

  /// Quita un estudiante de la lista de clase.
  Future<void> quitarEstudiante(String grupoId, String correo);

  /// Clases de recuperación del curso, en tiempo real.
  Stream<List<Recuperacion>> recuperaciones(String grupoId);

  /// Programa una clase de recuperación (fecha y hora fuera del horario).
  Future<void> programarRecuperacion(
    String grupoId,
    Recuperacion recuperacion,
    String docenteUid,
  );

  /// Elimina una clase de recuperación programada.
  Future<void> eliminarRecuperacion(String grupoId, String recuperacionId);

  /// Ubicación actual del celular (pide permiso si hace falta).
  Future<({double latitud, double longitud})> obtenerUbicacionActual();

  /// Abre el selector de archivos y lee la lista de estudiantes.
  /// Devuelve null si el docente cancela.
  /// Lanza CursoError con el motivo si el archivo no tiene el formato.
  Future<ResultadoImportacion?> importarEstudiantes();
}
