import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/facultad.dart';
import '../../domain/entities/programa.dart';
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

  // ---------- Programas ----------

  CollectionReference<Map<String, dynamic>> _programas(String facultadId) =>
      _facultades.doc(facultadId).collection('programas');

  Stream<List<Programa>> programas(String facultadId) =>
      _programas(facultadId).snapshots().map((s) {
        final lista = s.docs.map(ProgramaModel.fromFirestore).toList();
        lista.sort(
          (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
        );
        return lista;
      });

  Future<int> contarProgramas(String facultadId) async {
    final conteo = await _programas(facultadId).count().get();
    return conteo.count ?? 0;
  }

  Future<Programa> crearPrograma({
    required String facultadId,
    required String id,
    required String nombre,
    required String docenteUid,
  }) async {
    final facultadRef = _facultades.doc(facultadId);
    final ref = _programas(facultadId).doc(id);
    await _db.runTransaction((t) async {
      final facultad = await t.get(facultadRef);
      if (!facultad.exists) {
        throw const FacultadError('La facultad ya no existe');
      }
      final actual = await t.get(ref);
      if (actual.exists) {
        throw FacultadError('Ya existe "${actual.get('nombre')}"');
      }
      t.set(ref, FacultadModel.toMap(nombre, docenteUid));
    });
    return Programa(
      id: id,
      facultadId: facultadId,
      nombre: nombre,
      creadaPor: docenteUid,
    );
  }

  Future<void> eliminarPrograma(String facultadId, String programaId) =>
      _programas(facultadId).doc(programaId).delete();

  Future<void> asignarProgramaEstudiante({
    required String uid,
    required Facultad facultad,
    required Programa programa,
  }) => _db.collection('usuarios').doc(uid).update({
    'facultadId': facultad.id,
    'facultadNombre': facultad.nombre,
    'programaId': programa.id,
    'programaNombre': programa.nombre,
  });
}
