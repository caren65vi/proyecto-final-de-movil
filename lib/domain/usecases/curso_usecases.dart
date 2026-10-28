import '../entities/curso.dart';
import '../entities/estudiante_inscrito.dart';
import '../repositories/curso_repository.dart';

/// Casos de uso de cursos: validan los datos y llaman al repositorio.

class CrearCurso {
  final CursoRepository repositorio;
  CrearCurso(this.repositorio);

  Future<String> call(Curso curso, List<EstudianteInscrito> estudiantes) async {
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
    return repositorio.crearCurso(curso, estudiantes);
  }
}

class ObtenerMiUbicacion {
  final CursoRepository repositorio;
  ObtenerMiUbicacion(this.repositorio);

  Future<({double latitud, double longitud})> call() =>
      repositorio.obtenerUbicacionActual();
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
