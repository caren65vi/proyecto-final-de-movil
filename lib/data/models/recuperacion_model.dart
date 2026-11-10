import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/recuperacion.dart';

/// Convierte grupos/{id}/recuperaciones/{id} en la entidad Recuperacion.
/// La fecha se guarda como texto "AAAA-MM-DD" para que el servidor la
/// compare con el día de hoy sin problemas de zona horaria.
class RecuperacionModel {
  static String _dia(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static Map<String, dynamic> toMap(Recuperacion r, String docenteUid) => {
    'fecha': _dia(r.fecha),
    'inicio': r.inicio,
    'fin': r.fin,
    'motivo': r.motivo,
    'creadaPor': docenteUid,
    'creadaEn': FieldValue.serverTimestamp(),
  };

  static Recuperacion fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    final partes = (data['fecha'] as String? ?? '1970-01-01').split('-');
    return Recuperacion(
      id: doc.id,
      fecha: DateTime(
        int.parse(partes[0]),
        int.parse(partes[1]),
        int.parse(partes[2]),
      ),
      inicio: data['inicio'] as String? ?? '00:00',
      fin: data['fin'] as String? ?? '00:00',
      motivo: data['motivo'] as String? ?? '',
    );
  }
}
