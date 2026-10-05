import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/usuario.dart';

class UsuarioModel extends Usuario {
  const UsuarioModel({
    required super.uid,
    required super.nombre,
    required super.correo,
    required super.rol,
    required super.fechaCreacion,
  });

  // Convierte un documento de Firestore en un UsuarioModel
  factory UsuarioModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return UsuarioModel(
      uid: doc.id,
      nombre: data['nombre'] ?? '',
      correo: data['correo'] ?? '',
      rol: data['rol'] ?? '',
      fechaCreacion:
          (data['fechaCreacion'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Convierte el UsuarioModel en un mapa para guardarlo en Firestore
  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'correo': correo,
        'rol': rol,
        'fechaCreacion': Timestamp.fromDate(fechaCreacion),
      };
}
