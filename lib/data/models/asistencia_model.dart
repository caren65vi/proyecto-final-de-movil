import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/asistencia.dart';

/// Convierte un documento de sesiones/{id}/asistencias/{id} en la entidad Asistencia.
class AsistenciaModel {
  static Asistencia fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data()!;
    return Asistencia(
      correo: document.id,
      nombre: data['nombre'] as String? ?? '',
      estado: data['estado'] as String? ?? 'ausente',
      horas: (data['horas'] as num? ?? 0).toDouble(),
      metodo: data['metodo'] as String? ?? 'qr',
      registradaEn: (data['registradaEn'] as Timestamp?)?.toDate(),
      justificacion: data['justificacion'] as String?,
    );
  }
}
