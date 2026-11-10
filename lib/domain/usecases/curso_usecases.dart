import '../entities/curso.dart';
import '../entities/estudiante_inscrito.dart';
import '../entities/recuperacion.dart';
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

// ---------- Clases de recuperación ----------

class ObtenerRecuperaciones {
  final CursoRepository repositorio;
  ObtenerRecuperaciones(this.repositorio);

  Stream<List<Recuperacion>> call(String grupoId) =>
      repositorio.recuperaciones(grupoId);
}

/// Programa una clase de recuperación. Solo se acepta si cae dentro del
/// período del curso, todavía no ha pasado y no choca con el horario normal.
class ProgramarRecuperacion {
  final CursoRepository repositorio;
  ProgramarRecuperacion(this.repositorio);

  static const largoMaximoMotivo = 120;

  static int _minutos(String hora) {
    final partes = hora.split(':');
    return int.parse(partes[0]) * 60 + int.parse(partes[1]);
  }

  Future<void> call(
    Curso curso,
    Recuperacion recuperacion,
    String docenteUid,
  ) async {
    final desde = _minutos(recuperacion.inicio);
    final hasta = _minutos(recuperacion.fin);
    if (hasta <= desde) {
      throw const CursoError('La hora de fin debe ser después del inicio');
    }
    if (!curso.enPeriodo(recuperacion.fecha)) {
      throw const CursoError(
        'La fecha debe estar dentro del período del curso',
      );
    }
    if (recuperacion.yaPaso()) {
      throw const CursoError('Esa fecha y hora ya pasaron');
    }
    if (recuperacion.motivo.length > largoMaximoMotivo) {
      throw const CursoError(
        'El motivo no puede tener más de $largoMaximoMotivo caracteres',
      );
    }
    // No puede cruzarse con una clase normal de ese mismo día
    for (final bloque in curso.horario) {
      if (bloque.dia != recuperacion.fecha.weekday) continue;
      final cruza =
          desde < _minutos(bloque.fin) && hasta > _minutos(bloque.inicio);
      if (cruza) {
        throw CursoError(
          'Se cruza con la clase normal de ${bloque.inicio} a ${bloque.fin}',
        );
      }
    }
    if (curso.id == null) {
      throw const CursoError('El curso todavía no se ha guardado');
    }
    await repositorio.programarRecuperacion(
      curso.id!,
      Recuperacion(
        fecha: recuperacion.fecha,
        inicio: recuperacion.inicio,
        fin: recuperacion.fin,
        motivo: recuperacion.motivo.trim(),
      ),
      docenteUid,
    );
  }
}

class EliminarRecuperacion {
  final CursoRepository repositorio;
  EliminarRecuperacion(this.repositorio);

  Future<void> call(String grupoId, String recuperacionId) =>
      repositorio.eliminarRecuperacion(grupoId, recuperacionId);
}
