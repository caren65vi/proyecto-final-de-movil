import '../entities/asistencia.dart';

/// Error con un mensaje listo para mostrar.
class AsistenciaError implements Exception {
  final String mensaje;
  const AsistenciaError(this.mensaje);

  @override
  String toString() => mensaje;
}

/// Contrato: sesiones de clase, QR y registros de asistencia.
abstract class AsistenciaRepository {
  /// Abre (o retoma) la sesión de la clase de ahora.
  Future<({String sesionId, String token})> abrirSesion(String grupoId);

  /// Cambia el token del QR.
  Future<String> renovarQR(String grupoId, String sesionId);

  /// Cierra la sesión: marca ausentes y suma las horas.
  Future<void> cerrarSesion(String grupoId, String sesionId);

  /// El estudiante registra su asistencia (la ubicación la lee el repositorio).
  Future<void> registrarAsistencia({
    required String grupoId,
    required String sesionId,
    required String token,
  });

  /// Asistencias de una sesión, en tiempo real.
  Stream<List<Asistencia>> asistencias(String grupoId, String sesionId);

  /// Token actual del QR, en tiempo real (cambia tras cada registro).
  Stream<String> tokenQR(String grupoId, String sesionId);
}
