class Sesion {
  final String id;
  final String grupoId;
  final DateTime fecha;
  final double horas;
  final String estado;
  final int presentes;
  final int ausentes;
  final int justificadas;

  const Sesion({
    required this.id,
    required this.grupoId,
    required this.fecha,
    required this.horas,
    required this.estado,
    required this.presentes,
    required this.ausentes,
    required this.justificadas,
  });

  bool get abierta => estado == 'abierta';

  int get total => presentes + ausentes + justificadas;

  // De 0 a 1; solo cuentan los presentes (las justificadas van aparte)
  double get porcentaje => total == 0 ? 0 : presentes / total;
}
