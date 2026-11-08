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
  final int totalEstudiantes;
  final int sesionesCerradas;
  final int totalPresentes;
  final int totalAusentes;
  final int totalJustificadas;

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
    this.totalEstudiantes = 0,
    this.sesionesCerradas = 0,
    this.totalPresentes = 0,
    this.totalAusentes = 0,
    this.totalJustificadas = 0,
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

  int get totalRegistros => totalPresentes + totalAusentes + totalJustificadas;

  ///asistencias del curso
  double get porcentajeAsistencia => totalRegistros == 0
      ? 0
      : totalPresentes * totalJustificadas / totalRegistros;


      //promedio por clase 

  /// Bloque del horario que está en curso en [momento] (por defecto, ahora).
  /// Cuenta desde 15 minutos antes del inicio, igual que el servidor.
  BloqueHorario? bloqueEnCurso([DateTime? momento]) {
    final ahora = momento ?? DateTime.now();
    final minutos = ahora.hour * 60 + ahora.minute;
    int aMinutos(String hora) {
      final partes = hora.split(':');
      return int.parse(partes[0]) * 60 + int.parse(partes[1]);
    }

    for (final bloque in horario) {
      if (bloque.dia == ahora.weekday &&
          minutos >= aMinutos(bloque.inicio) - 15 &&
          minutos <= aMinutos(bloque.fin)) {
        return bloque;
      }
    }
    return null;
  }
}
