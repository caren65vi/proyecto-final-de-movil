import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/curso.dart';
import '../../domain/entities/estudiante_inscrito.dart';
import '../models/curso_model.dart';
import '../models/estudiante_inscrito_model.dart';

/// Habla directamente con Cloud Firestore (colección "grupos").
class CursoDatasource {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _grupos =>
      _db.collection('grupos');

  // Cursos cuyo dueño es el docente (las reglas solo permiten esta consulta)
  Stream<List<Curso>> misCursos(String docenteUid) {
    return _grupos
        .where('docenteUid', isEqualTo: docenteUid)
        .snapshots()
        .map(
          (snap) => [
            for (final doc in snap.docs) CursoModel.fromFirestore(doc),
          ],
        );
  }

  // Guarda el curso y luego su lista de estudiantes
  Future<String> crearCurso(
    Curso curso,
    List<EstudianteInscrito> estudiantes,
  ) async {
    // Primero el curso: las reglas revisan que el docente sea su dueño
    final ref = await _grupos.add(CursoModel.toMap(curso));

    // Firestore acepta máximo 500 escrituras por lote
    for (var i = 0; i < estudiantes.length; i += 500) {
      final lote = _db.batch();
      for (final e in estudiantes.skip(i).take(500)) {
        lote.set(
          ref.collection('inscripciones').doc(e.correo),
          EstudianteInscritoModel.toMap(e),
        );
      }
      await lote.commit();
    }
    return ref.id;
  }
}
