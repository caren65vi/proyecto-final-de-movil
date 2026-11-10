import '../entities/facultad.dart';

/// Error con un mensaje listo para mostrar al docente.
class FacultadError implements Exception {
  final String mensaje;
  const FacultadError(this.mensaje);

  @override
  String toString() => mensaje;
}

/// Contrato: facultades que los docentes eligen al crear un curso.
abstract class FacultadRepository {
  /// Todas las facultades, ordenadas por nombre, en tiempo real.
  Stream<List<Facultad>> facultades();

  /// Crea la facultad con ese ID; falla si ya existe.
  Future<Facultad> crearFacultad({
    required String id,
    required String nombre,
    required String docenteUid,
  });

  /// Elimina una facultad (solo la puede borrar quien la creó).
  Future<void> eliminarFacultad(String id);
}
