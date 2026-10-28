/// Un bloque semanal de clase: día y rango de horas.
class BloqueHorario {
  final int dia; // 1 = lunes … 6 = sábado
  final String inicio; // "08:00"
  final String fin; // "10:00"

  const BloqueHorario({
    required this.dia,
    required this.inicio,
    required this.fin,
  });

  // Duración en horas (ej. 08:00 a 10:00 → 2.0)
  double get horas => (_minutos(fin) - _minutos(inicio)) / 60;

  static int _minutos(String hora) {
    final partes = hora.split(':');
    return int.parse(partes[0]) * 60 + int.parse(partes[1]);
  }
}
