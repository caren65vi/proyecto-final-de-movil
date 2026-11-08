import '../entities/curso.dart';
import '../entities/estudiante_inscrito.dart';
import '../repositories/curso_repository.dart';

/// Casos de uso de cursos: validan los datos y llaman al repositorio.

void _validarCurso(Curso curso) {
  if (curso.nombreMateria.trim().isEmpty) {
    throw const CursoError('Escribe el nombre del curso');
  }
  if (curso.horario.isEmpty) {
    throw const CursoError('Agrega al menos un horario de clase');
  }
  if (curso.fechaFin.isBefore(curso.fechaInicio)) {
    throw const CursoError('La fecha de fin debe ser posterior al inicio');
  }
  if (curso.horasTotales <= 0) {
    throw const CursoError(
      'Ningún día del horario cae dentro del período elegido',
    );
  }
}

class CrearCurso {
  final CursoRepository repositorio;
  CrearCurso(this.repositorio);

  Future<String> call(Curso curso, List<EstudianteInscrito> estudiantes) async {
    _validarCurso(curso);
    return repositorio.crearCurso(curso, estudiantes);
  }
}

class ObtenerMiUbicacion {
  final CursoRepository repositorio;
  ObtenerMiUbicacion(this.repositorio);

  Future<({double latitud, double longitud})> call() =>
      repositorio.obtenerUbicacionActual();
}

class ObtenerMisCursos {
  final CursoRepository repositorio;
  ObtenerMisCursos(this.repositorio);

  Stream<List<Curso>> call(String docenteUid) =>
      repositorio.misCursos(docenteUid);
}

class ImportarEstudiantes {
  final CursoRepository repositorio;
  ImportarEstudiantes(this.repositorio);

  Future<({String nombreArchivo, List<EstudianteInscrito> estudiantes})?>
  call() async {
    final resultado = await repositorio.importarEstudiantes();
    if (resultado != null && resultado.estudiantes.isEmpty) {
      throw const CursoError('El archivo no tiene estudiantes con correo');
    }
    return resultado;
  }
}

class ObtenerCurso {
  final CursoRepository repositorio;
  ObtenerCurso(this.repositorio);

  Stream<Curso> call(String grupoId) => repositorio.curso(grupoId);
}

class ObtenerEstudiantes {
  final CursoRepository repositorio;
  ObtenerEstudiantes(this.repositorio);

  Stream<List<EstudianteInscrito>> call(String grupoId) =>
      repositorio.estudiantes(grupoId);
}

class EditarCurso {
  final CursoRepository repositorio;
  EditarCurso(this.repositorio);

  Future<void> call(Curso curso) async {
    if (curso.id == null) {
      throw const CursoError('Este curso todavía no está guardado');
    }
    _validarCurso(curso);
    await repositorio.editarCurso(curso);
  }
}

class AgregarEstudiante {
  final CursoRepository repositorio;
  AgregarEstudiante(this.repositorio);

  Future<void> call(
    String grupoId, {
    required String correo,
    required String nombre,
    String? codigo,
  }) async {
    final correoLimpio = correo.trim().toLowerCase();
    if (!correoLimpio.endsWith('@udla.edu.co')) {
      throw const CursoError('Usa el correo institucional @udla.edu.co');
    }
    if (nombre.trim().isEmpty) {
      throw const CursoError('Escribe el nombre del estudiante');
    }
    final codigoLimpio = codigo?.trim() ?? '';
    await repositorio.agregarEstudiante(
      grupoId,
      EstudianteInscrito(
        correo: correoLimpio,
        nombre: nombre.trim(),
        codigoEstudiante: codigoLimpio.isEmpty ? null : codigoLimpio,
      ),
    );
  }
}

class QuitarEstudiante {
  final CursoRepository repositorio;
  QuitarEstudiante(this.repositorio);

  Future<void> call(String grupoId, String correo) =>
      repositorio.quitarEstudiante(grupoId, correo);
}
