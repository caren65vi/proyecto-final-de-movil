import 'bloque_horario.dart';

/// Curso que dicta un docente. Se guarda en la colección "grupos".
class Curso {
  final String? id; // null mientras no se ha guardado
  final String nombreMateria;
  final String facultad;
  final String numeroGrupo;
  final String aula;
  final String docenteUid;
  final String docenteNombre;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final List<BloqueHorario> horario;
  final double latitud;
  final double longitud;
  final int radioMetros;
  final double metaAsistencia; // 0.8 = 80 %

  const Curso({
    this.id,
    required this.nombreMateria,
    required this.facultad,
    required this.numeroGrupo,
    required this.aula,
    required this.docenteUid,
    required this.docenteNombre,
    required this.fechaInicio,
    required this.fechaFin,
    required this.horario,
    required this.latitud,
    required this.longitud,
    required this.radioMetros,
    this.metaAsistencia = 0.8,
  });

  // Semestre según el mes de inicio: "2026-1" (ene–jun) o "2026-2" (jul–dic)
  String get periodoId =>
      '${fechaInicio.year}-${fechaInicio.month <= 6 ? 1 : 2}';

  // Suma las horas de cada clase que cae entre fechaInicio y fechaFin
  int get horasTotales {
    var total = 0.0;
    var dia = DateTime(fechaInicio.year, fechaInicio.month, fechaInicio.day);
    final ultimo = DateTime(fechaFin.year, fechaFin.month, fechaFin.day);
    while (!dia.isAfter(ultimo)) {
      for (final bloque in horario) {
        if (bloque.dia == dia.weekday) total += bloque.horas;
      }
      dia = DateTime(dia.year, dia.month, dia.day + 1);
    }
    return total.round();
  }
}
