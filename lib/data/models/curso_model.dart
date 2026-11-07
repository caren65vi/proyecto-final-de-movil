import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/bloque_horario.dart';
import '../../domain/entities/curso.dart';

/// Convierte un Curso en el mapa que se guarda en grupos/{id}.
class CursoModel {
  static Curso fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final ubicacion = data['ubicacion'] as GeoPoint;
    final horario = (data['horario'] as List<dynamic>?) ?? const [];

    return Curso(
      id: doc.id,
      nombreMateria: data['nombreMateria'] ?? '',
      facultad: data['facultad'] ?? '',
      numeroGrupo: data['numeroGrupo'] ?? '',
      aula: data['aula'] ?? '',
      docenteUid: data['docenteUid'] ?? '',
      docenteNombre: data['docenteNombre'] ?? '',
      fechaInicio: (data['fechaInicio'] as Timestamp).toDate(),
      fechaFin: (data['fechaFin'] as Timestamp).toDate(),
      horario: horario
          .map(
            (bloque) => BloqueHorario(
              dia: (bloque['dia'] as num).toInt(),
              inicio: bloque['inicio'] ?? '',
              fin: bloque['fin'] ?? '',
            ),
          )
          .toList(growable: false),
      latitud: ubicacion.latitude,
      longitud: ubicacion.longitude,
      radioMetros: (data['radioMetros'] as num).toInt(),
      metaAsistencia: ((data['metaAsistencia'] as num?) ?? 0.8).toDouble(),
      totalEstudiantes: ((data['totalEstudiantes'] as num?) ?? 0).toInt(),
    );
  }

  static Map<String, dynamic> toMap(Curso curso) => {
    'periodoId': curso.periodoId,
    'nombreMateria': curso.nombreMateria,
    'facultad': curso.facultad,
    'numeroGrupo': curso.numeroGrupo,
    'aula': curso.aula,
    'docenteUid': curso.docenteUid,
    'docenteNombre': curso.docenteNombre,
    'fechaInicio': Timestamp.fromDate(curso.fechaInicio),
    'fechaFin': Timestamp.fromDate(curso.fechaFin),
    'horasTotales': curso.horasTotales,
    'metaAsistencia': curso.metaAsistencia,
    'horario': [
      for (final bloque in curso.horario)
        {'dia': bloque.dia, 'inicio': bloque.inicio, 'fin': bloque.fin},
    ],
    'ubicacion': GeoPoint(curso.latitud, curso.longitud),
    'radioMetros': curso.radioMetros,
    // Contadores de asistencia; los actualiza el servidor
    'sesionesCerradas': 0,
    'totalPresentes': 0,
    'totalAusentes': 0,
    'totalJustificadas': 0,
    'fechaCreacion': FieldValue.serverTimestamp(),
  };
}
