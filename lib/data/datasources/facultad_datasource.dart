import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/facultad.dart';
import '../../domain/repositories/facultad_repository.dart';
import '../models/facultad_model.dart';

/// Habla directamente con Cloud Firestore (colección "facultades").
class FacultadDatasource {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _facultades =>
      _db.collection('facultades');

  Stream<List<Facultad>> facultades() => _facultades.snapshots().map((s) {
    final lista = s.docs.map(FacultadModel.fromFirestore).toList();
    lista.sort(
      (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
    );
    return lista;
  });

  // En una transacción para que dos docentes no creen la misma a la vez
  Future<Facultad> crearFacultad({
    required String id,
    required String nombre,
    required String docenteUid,
  }) async {
    final ref = _facultades.doc(id);
    await _db.runTransaction((t) async {
      final actual = await t.get(ref);
      if (actual.exists) {
        throw FacultadError('Ya existe "${actual.get('nombre')}"');
      }
      t.set(ref, FacultadModel.toMap(nombre, docenteUid));
    });
    return Facultad(id: id, nombre: nombre, creadaPor: docenteUid);
  }

  Future<void> eliminarFacultad(String id) => _facultades.doc(id).delete();
}
