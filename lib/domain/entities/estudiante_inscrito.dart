/// Estudiante de la lista de clase; se inscribe por su correo.
class EstudianteInscrito {
  final String correo;
  final String nombre;
  final String? codigoEstudiante;
  final String? uid; // se llena cuando el estudiante entra a la app
  final double horasAsistidas;
  final double horasFalta;
  final double horasJustificadas;


  const EstudianteInscrito({
    required this.correo,
    required this.nombre,
    this.codigoEstudiante,
    this.uid,
    this.horasAsistidas = 0,
    this.horasFalta = 0,
    this.horasJustificadas = 0,
  });

  // Horas de clase que ya pasaron para este estudiante
  double get horasDictadas => horasAsistidas + horasFalta + horasJustificadas;

  // Asistencia de 0 a 1; solo cuentan las horas asistidas
  // (las justificadas se muestran aparte).
  // Si todavía no hay clases dictadas, se toma como 100 %.
  double get porcentaje =>
      horasDictadas == 0 ? 1 : horasAsistidas / horasDictadas;
}
