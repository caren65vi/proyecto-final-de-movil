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
}
