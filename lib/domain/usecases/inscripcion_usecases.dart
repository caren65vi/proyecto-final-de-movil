import '../entities/materia_estudiante.dart';
import '../repositories/curso_repository.dart';
import '../repositories/inscripcion_repository.dart';

class ObtenerMisMaterias {
  final InscripcionRepository repositorio;
  ObtenerMisMaterias(this.repositorio);

  // El ID de la inscripción es el correo en minúscula
  Stream<List<MateriaEstudiante>> call(String correo) =>
      repositorio.misMaterias(correo.trim().toLowerCase());
}

class EnlazarCuenta {
  final InscripcionRepository repositorio;
  EnlazarCuenta(this.repositorio);

  Future<void> call(String correo, String uid) =>
      repositorio.enlazarCuenta(correo.trim().toLowerCase(), uid);
}

/// El estudiante escanea el QR de inscripción del docente.
/// No pide ubicación: puede inscribirse desde cualquier lugar.
class InscribirseConQR {
  final InscripcionRepository repositorio;
  InscribirseConQR(this.repositorio);

  /// Devuelve el nombre de la materia en la que quedó inscrito.
  Future<String> call(String contenidoQR) async {
    final partes = contenidoQR.split('|');
    if (partes.length == 4 && partes[0] == 'ceiba') {
      throw const CursoError(
        'Este código es para registrar asistencia, no para inscribirse',
      );
    }
    if (partes.length != 3 ||
        partes[0] != 'ceiba-inscripcion' ||
        partes[1].isEmpty ||
        partes[2].isEmpty) {
      throw const CursoError('Este código QR no es de inscripción de Ceiba');
    }
    return repositorio.inscribirseConQR(grupoId: partes[1], token: partes[2]);
  }
}
