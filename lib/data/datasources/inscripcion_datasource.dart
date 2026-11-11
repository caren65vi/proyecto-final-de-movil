import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../domain/entities/materia_estudiante.dart';
import '../models/curso_model.dart';
import '../models/estudiante_inscrito_model.dart';

/// Habla con Firestore para las inscripciones del estudiante.
class InscripcionDatasource {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // El servidor revisa el código y crea la inscripción
  Future<String> inscribirseConQR(String grupoId, String token) async {
    final resultado = await _functions.httpsCallable('inscribirseConQR').call({
      'grupoId': grupoId,
      'token': token,
    });
    return (resultado.data as Map)['nombreMateria'] as String? ?? '';
  }

  // Todas las inscripciones de un correo, en cualquier curso
  Query<Map<String, dynamic>> _misInscripciones(String correo) =>
      _db.collectionGroup('inscripciones').where('correo', isEqualTo: correo);

  // Por cada inscripción se lee su curso (el documento "padre")
  Stream<List<MateriaEstudiante>> misMaterias(String correo) =>
      _misInscripciones(correo).snapshots().asyncMap((snapshot) async {
        final materias = await Future.wait(
          snapshot.docs.map((doc) async {
            final grupo = await doc.reference.parent.parent!.get();
            if (!grupo.exists) return null; // el curso fue borrado
            return MateriaEstudiante(
              curso: CursoModel.fromFirestore(grupo),
              inscripcion: EstudianteInscritoModel.fromDocument(doc),
            );
          }),
        );
        final lista = materias.whereType<MateriaEstudiante>().toList();
        lista.sort(
          (a, b) => a.curso.nombreMateria.compareTo(b.curso.nombreMateria),
        );
        return lista;
      });

  // Escribe el uid solo donde todavía está en null
  Future<void> enlazarCuenta(String correo, String uid) async {
    final snapshot = await _misInscripciones(correo).get();
    final lote = _db.batch();
    var cambios = 0;
    for (final doc in snapshot.docs) {
      if (doc.data()['uid'] == null) {
        lote.update(doc.reference, {'uid': uid});
        cambios++;
      }
    }
    if (cambios > 0) await lote.commit();
  }
}
