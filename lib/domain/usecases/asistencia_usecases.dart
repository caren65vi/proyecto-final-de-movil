import '../entities/asistencia.dart';
import '../repositories/asistencia_repository.dart';

class AbrirSesion {
  final AsistenciaRepository repositorio;
  AbrirSesion(this.repositorio);

  Future<({String sesionId, String token})> call(String grupoId) =>
      repositorio.abrirSesion(grupoId);
}

class RenovarQR {
  final AsistenciaRepository repositorio;
  RenovarQR(this.repositorio);

  Future<String> call(String grupoId, String sesionId) =>
      repositorio.renovarQR(grupoId, sesionId);
}

// Se llama CerrarAsistencia para no confundirse con CerrarSesion (login)
class CerrarAsistencia {
  final AsistenciaRepository repositorio;
  CerrarAsistencia(this.repositorio);

  Future<void> call(String grupoId, String sesionId) =>
      repositorio.cerrarSesion(grupoId, sesionId);
}

class ObtenerAsistencias {
  final AsistenciaRepository repositorio;
  ObtenerAsistencias(this.repositorio);

  Stream<List<Asistencia>> call(String grupoId, String sesionId) =>
      repositorio.asistencias(grupoId, sesionId);
}

/// Asistencia de las últimas semanas de un grupo, de 0 a 1 (solo presentes).
/// La lista va de la semana más antigua a la actual; null = no hubo clases.
class ObtenerTendenciaSemanal {
  final AsistenciaRepository repositorio;
  ObtenerTendenciaSemanal(this.repositorio);

  /// Semanas que se muestran en la tendencia.
  static const semanasPorDefecto = 4;

  Stream<List<double?>> call(
    String grupoId, {
    int semanas = semanasPorDefecto,
  }) {
    final hoy = DateTime.now();
    // La última semana termina hoy; se cuentan días completos
    final inicio = DateTime(
      hoy.year,
      hoy.month,
      hoy.day,
    ).subtract(Duration(days: 7 * semanas - 1));

    return repositorio.sesionesDesde(grupoId, inicio).map((sesiones) {
      final presentes = List.filled(semanas, 0);
      final totales = List.filled(semanas, 0);
      for (final sesion in sesiones) {
        final semana = sesion.fecha.difference(inicio).inDays ~/ 7;
        if (semana < 0 || semana >= semanas) continue;
        presentes[semana] += sesion.presentes;
        totales[semana] += sesion.total;
      }
      return [
        for (var i = 0; i < semanas; i++)
          totales[i] == 0 ? null : presentes[i] / totales[i],
      ];
    });
  }
}

/// Token del QR en vivo: el servidor lo cambia después de cada registro,
/// así el docente siempre muestra un código nuevo para el siguiente estudiante.
class EscucharTokenQR {
  final AsistenciaRepository repositorio;
  EscucharTokenQR(this.repositorio);

  Stream<String> call(String grupoId, String sesionId) =>
      repositorio.tokenQR(grupoId, sesionId);
}

/// El QR lleva el texto: ceiba|grupoId|sesionId|token
class RegistrarAsistenciaQR {
  final AsistenciaRepository repositorio;
  RegistrarAsistenciaQR(this.repositorio);

  /// Texto que debe llevar el QR del docente.
  static String contenido(String grupoId, String sesionId, String token) =>
      'ceiba|$grupoId|$sesionId|$token';

  Future<void> call(String contenidoQR) async {
    final partes = contenidoQR.split('|');
    if (partes.length != 4 || partes[0] != 'ceiba') {
      throw const AsistenciaError('Este código QR no es de Ceiba');
    }
    await repositorio.registrarAsistencia(
      grupoId: partes[1],
      sesionId: partes[2],
      token: partes[3],
    );
  }
}
