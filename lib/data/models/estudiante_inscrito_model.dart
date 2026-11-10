import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/estudiante_inscrito.dart';

/// Convierte un estudiante en el mapa de grupos/{id}/inscripciones/{correo}.
class EstudianteInscritoModel {
  static Map<String, dynamic> toMap(EstudianteInscrito estudiante) => {
    'correo': estudiante.correo,
    'nombre': estudiante.nombre,
    'uid': null, // se llena cuando el estudiante entra a la app
    'codigoEstudiante': estudiante.codigoEstudiante,
    'horasAsistidas': 0,
    'horasFalta': 0,
    'horasJustificadas': 0,
    'fechaInscripcion': FieldValue.serverTimestamp(),
  };

  /// Convierte un documento de inscripciones/{correo} en la entidad.
  static EstudianteInscrito fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data()!;
    return EstudianteInscrito(
      correo: document.id,
      nombre: data['nombre'] as String? ?? '',
      codigoEstudiante: data['codigoEstudiante'] as String?,
      uid: data['uid'] as String?,
      horasAsistidas: (data['horasAsistidas'] as num? ?? 0).toDouble(),
      horasFalta: (data['horasFalta'] as num? ?? 0).toDouble(),
      horasJustificadas: (data['horasJustificadas'] as num? ?? 0).toDouble(),
    );
  }
}
