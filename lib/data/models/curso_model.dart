import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/bloque_horario.dart';
import '../../domain/entities/curso.dart';

/// Convierte un Curso en el mapa que se guarda en grupos/{id}, y al revés.
class CursoModel {
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

  // Lee un documento de grupos/{id}
  static Curso fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final ubicacion = data['ubicacion'] as GeoPoint?;
    return Curso(
      id: doc.id,
      nombreMateria: data['nombreMateria'] ?? '',
      facultad: data['facultad'] ?? '',
      numeroGrupo: '${data['numeroGrupo'] ?? ''}',
      aula: data['aula'] ?? '',
      docenteUid: data['docenteUid'] ?? '',
      docenteNombre: data['docenteNombre'] ?? '',
      fechaInicio:
          (data['fechaInicio'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fechaFin: (data['fechaFin'] as Timestamp?)?.toDate() ?? DateTime.now(),
      horario: [
        for (final bloque in (data['horario'] as List? ?? []))
          BloqueHorario(
            dia: (bloque['dia'] as num).toInt(),
            inicio: bloque['inicio'] as String,
            fin: bloque['fin'] as String,
          ),
      ],
      latitud: ubicacion?.latitude ?? 0,
      longitud: ubicacion?.longitude ?? 0,
      radioMetros: (data['radioMetros'] as num?)?.toInt() ?? 0,
      metaAsistencia: (data['metaAsistencia'] as num?)?.toDouble() ?? 0.8,
    );
  }
}
