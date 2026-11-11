import '../entities/materia_estudiante.dart';

/// Contrato: lo que el estudiante hace con sus inscripciones.
/// Los errores se lanzan como CursoError (curso_repository.dart).
abstract class InscripcionRepository {
  /// Materias en las que está inscrito el correo, en tiempo real.
  Stream<List<MateriaEstudiante>> misMaterias(String correo);

  /// Inscribe al estudiante con el código QR del docente.
  /// Devuelve el nombre de la materia.
  Future<String> inscribirseConQR({
    required String grupoId,
    required String token,
  });

  /// Guarda el uid del estudiante en sus inscripciones que aún no lo tienen.
  Future<void> enlazarCuenta(String correo, String uid);
}
