import 'curso.dart';
import 'estudiante_inscrito.dart';

/// Una materia del estudiante: el curso y su inscripción (con sus horas).
class MateriaEstudiante {
  final Curso curso;
  final EstudianteInscrito inscripcion;

  const MateriaEstudiante({required this.curso, required this.inscripcion});
}
