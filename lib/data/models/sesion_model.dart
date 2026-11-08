import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/sesion.dart';

/// Convierte un documento de sesiones/{id} en la entidad Sesion.
class SesionModel {
  static Sesion fromDocument(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data()!;
    return Sesion(
      id: document.id,
      grupoId: data['grupoId'] as String? ?? '',
      // La hora del servidor puede llegar vacía un instante antes de guardarse
      fecha: (data['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
      horas: (data['horas'] as num? ?? 0).toDouble(),
      estado: data['estado'] as String? ?? 'abierta',
      presentes: (data['presentes'] as num? ?? 0).toInt(),
      ausentes: (data['ausentes'] as num? ?? 0).toInt(),
      justificadas: (data['justificadas'] as num? ?? 0).toInt(),
    );
  }
}
