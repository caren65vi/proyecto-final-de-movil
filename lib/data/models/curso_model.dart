import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/curso.dart';

/// Convierte un Curso en el mapa que se guarda en grupos/{id}.
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
}
