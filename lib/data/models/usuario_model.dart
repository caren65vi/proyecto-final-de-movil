import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/usuario.dart';

class UsuarioModel extends Usuario {
  const UsuarioModel({
    required super.uid,
    required super.nombre,
    required super.correo,
    required super.rol,
    required super.fechaCreacion,
    super.facultadId,
    super.facultadNombre,
    super.programaId,
    super.programaNombre,
  });

  // Convierte un documento de Firestore en un UsuarioModel
  factory UsuarioModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return UsuarioModel(
      uid: doc.id,
      nombre: data['nombre'] ?? '',
      correo: data['correo'] ?? '',
      rol: data['rol'] ?? '',
      fechaCreacion:
          (data['fechaCreacion'] as Timestamp?)?.toDate() ?? DateTime.now(),
      facultadId: data['facultadId'] as String?,
      facultadNombre: data['facultadNombre'] as String?,
      programaId: data['programaId'] as String?,
      programaNombre: data['programaNombre'] as String?,
    );
  }

  // Convierte el UsuarioModel en un mapa para guardarlo en Firestore
  Map<String, dynamic> toMap() => {
    'nombre': nombre,
    'correo': correo,
    'rol': rol,
    // Hora del servidor, no la del celular
    'fechaCreacion': FieldValue.serverTimestamp(),
  };
}
