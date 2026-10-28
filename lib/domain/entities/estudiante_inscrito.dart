/// Estudiante de la lista de clase; se inscribe por su correo.
class EstudianteInscrito {
  final String correo;
  final String nombre;
  final String? codigoEstudiante;

  const EstudianteInscrito({
    required this.correo,
    required this.nombre,
    this.codigoEstudiante,
  });
}
