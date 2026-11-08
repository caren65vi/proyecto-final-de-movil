import '../entities/materia_estudiante.dart';
import '../repositories/inscripcion_repository.dart';

class ObtenerMisMaterias {
  final InscripcionRepository repositorio;
  ObtenerMisMaterias(this.repositorio);

  // El ID de la inscripción es el correo en minúscula
  Stream<List<MateriaEstudiante>> call(String correo) =>
      repositorio.misMaterias(correo.trim().toLowerCase());
}

class EnlazarCuenta {
  final InscripcionRepository repositorio;
  EnlazarCuenta(this.repositorio);

  Future<void> call(String correo, String uid) =>
      repositorio.enlazarCuenta(correo.trim().toLowerCase(), uid);
}
