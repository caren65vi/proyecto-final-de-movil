import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/curso.dart';
import '../../domain/entities/estudiante_inscrito.dart';
import '../../domain/repositories/curso_repository.dart';
import '../models/curso_model.dart';
import '../models/estudiante_inscrito_model.dart';

/// Habla directamente con Cloud Firestore (colección "grupos").
class CursoDatasource {
  static const _camposEditables = {
    'nombreMateria',
    'facultad',
    'numeroGrupo',
    'aula',
    'docenteNombre',
    'periodoId',
    'fechaInicio',
    'fechaFin',
    'horasTotales',
    'metaAsistencia',
    'horario',
    'ubicacion',
    'radioMetros',
  };

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _grupos =>
      _db.collection('grupos');

  // Actualiza solo los campos editables; los contadores no se tocan.
  Future<void> editarCurso(Curso curso) {
    final datos = CursoModel.toMap(curso)
      ..removeWhere((campo, _) => !_camposEditables.contains(campo));

    return _grupos.doc(curso.id).update(datos);
  }

  // Crea la inscripción y suma 1 al total del curso en el mismo lote.
  Future<void> agregarEstudiante(
    String grupoId,
    EstudianteInscrito estudiante,
  ) async {
    final grupo = _grupos.doc(grupoId);
    final inscripcion = grupo
        .collection('inscripciones')
        .doc(estudiante.correo);
    if ((await inscripcion.get()).exists) {
      throw const CursoError('Ese estudiante ya está inscrito en el curso');
    }

    final lote = _db.batch();
    lote.set(inscripcion, EstudianteInscritoModel.toMap(estudiante));
    lote.update(grupo, {'totalEstudiantes': FieldValue.increment(1)});
    await lote.commit();
  }

  // Borra la inscripción y resta 1 al total del curso en el mismo lote.
  Future<void> quitarEstudiante(String grupoId, String correo) async {
    final grupo = _grupos.doc(grupoId);
    final lote = _db.batch();
    lote.delete(grupo.collection('inscripciones').doc(correo));
    lote.update(grupo, {'totalEstudiantes': FieldValue.increment(-1)});
    await lote.commit();
  }

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

  Stream<List<EstudianteInscrito>> estudiantes(String grupoId) => _grupos
      .doc(grupoId)
      .collection('inscripciones')
      .snapshots()
      .map((snapshot) {
        final lista = snapshot.docs
            .map(EstudianteInscritoModel.fromDocument)
            .toList();
        lista.sort((a, b) => a.nombre.compareTo(b.nombre));
        return lista;
      });
}
