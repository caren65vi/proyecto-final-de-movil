import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/facultad.dart';

/// Convierte un documento de facultades/{id} en la entidad Facultad, y al revés.
class FacultadModel {
  static Map<String, dynamic> toMap(String nombre, String docenteUid) => {
    'nombre': nombre,
    'creadaPor': docenteUid,
    'creadaEn': FieldValue.serverTimestamp(),
  };

  static Facultad fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Facultad(
      id: doc.id,
      nombre: data['nombre'] as String? ?? '',
      creadaPor: data['creadaPor'] as String? ?? '',
    );
  }
}
