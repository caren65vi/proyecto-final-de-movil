import '../entities/curso.dart';
import '../entities/estudiante_inscrito.dart';

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

  /// Ubicación actual del celular (pide permiso si hace falta).
  Future<({double latitud, double longitud})> obtenerUbicacionActual();

  /// Abre el selector de archivos y lee la lista de estudiantes.
  /// Devuelve null si el docente cancela.
  Future<({String nombreArchivo, List<EstudianteInscrito> estudiantes})?>
  importarEstudiantes();
}
