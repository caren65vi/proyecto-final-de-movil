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

  // Guarda el curso y luego su lista de estudiantes
  Future<String> crearCurso(
    Curso curso,
    List<EstudianteInscrito> estudiantes,
  ) async {
    // Primero el curso: las reglas revisan que el docente sea su dueño
    final ref = await _grupos.add({
      ...CursoModel.toMap(curso),
      'totalEstudiantes': estudiantes.length,
    });

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

  // Cursos del docente, en tiempo real, ordenados por nombre
  // (las reglas solo permiten esta consulta: where docenteUid == uid)
  Stream<List<Curso>> misCursos(String docenteUid) => _grupos
      .where('docenteUid', isEqualTo: docenteUid)
      .snapshots()
      .map((snapshot) {
        final cursos = snapshot.docs.map(CursoModel.fromFirestore).toList();
        cursos.sort((a, b) => a.nombreMateria.compareTo(b.nombreMateria));
        return cursos;
      });

  //un curso por su ID, si lo borran, simplemente deja de emitir
  Stream<Curso> curso(String grupoId) => _grupos
      .doc(grupoId)
      .snapshots()
      .where((doc) => doc.exists)
      .map(CursoModel.fromFirestore);

  //Lista de clase ordenada por nombre

  Stream<List<EstudianteInscrito>> estudiantes(String grupoId) =>
      _grupos.doc(grupoId).collection('inscripciones').snapshots().map((
        snapshot,
      ) {
        final lista = snapshot.docs
            .map(EstudianteInscritoModel.fromDocument)
            .toList();
        lista.sort((a, b) => a.nombre.compareTo(b.nombre));
        return lista;
      });
}
