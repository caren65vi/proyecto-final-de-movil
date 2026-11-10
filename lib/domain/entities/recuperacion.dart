import 'curso.dart';

/// Clase de recuperación: una clase extra, fuera del horario semanal, que el
/// docente programa con fecha y hora. Solo en esa ventana se puede tomar
/// asistencia (el servidor también lo comprueba).
/// Se guarda en grupos/{id}/recuperaciones/{id}.
class Recuperacion {
  final String? id; // null mientras no se ha guardado
  final DateTime fecha; // solo importa el día
  final String inicio; // "HH:MM"
  final String fin; // "HH:MM"
  final String motivo;

  const Recuperacion({
    this.id,
    required this.fecha,
    required this.inicio,
    required this.fin,
    this.motivo = '',
  });

  static int _minutos(String hora) {
    final partes = hora.split(':');
    return int.parse(partes[0]) * 60 + int.parse(partes[1]);
  }

  DateTime _conHora(String hora) {
    final m = _minutos(hora);
    return DateTime(fecha.year, fecha.month, fecha.day, m ~/ 60, m % 60);
  }

  DateTime get empieza => _conHora(inicio);
  DateTime get termina => _conHora(fin);

  /// Duración en horas (ej. 08:00 a 10:00 → 2.0).
  double get horas => (_minutos(fin) - _minutos(inicio)) / 60;

  /// Se puede tomar asistencia: desde [Curso.minutosAntes] antes del inicio
  /// hasta que termina.
  bool disponible([DateTime? momento]) {
    final ahora = momento ?? DateTime.now();
    return !ahora.isBefore(
          empieza.subtract(const Duration(minutes: Curso.minutosAntes)),
        ) &&
        !ahora.isAfter(termina);
  }

  /// Ya pasó la hora de terminar.
  bool yaPaso([DateTime? momento]) =>
      (momento ?? DateTime.now()).isAfter(termina);
}
