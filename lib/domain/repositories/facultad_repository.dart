import '../entities/facultad.dart';
import '../entities/programa.dart';

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

  // ---------- Programas de una facultad ----------

  /// Programas de la facultad, ordenados por nombre, en tiempo real.
  Stream<List<Programa>> programas(String facultadId);

  /// Cuántos programas tiene la facultad (para no borrarla si tiene).
  Future<int> contarProgramas(String facultadId);

  /// Crea el programa con ese ID dentro de la facultad; falla si ya existe.
  Future<Programa> crearPrograma({
    required String facultadId,
    required String id,
    required String nombre,
    required String docenteUid,
  });

  /// Elimina un programa (solo lo puede borrar quien lo creó).
  Future<void> eliminarPrograma(String facultadId, String programaId);

  /// Programa de cada estudiante (uid → nombre del programa), para que el
  /// docente lo vea en la lista del curso. Los que no tienen no aparecen.
  Future<Map<String, String>> programasDeEstudiantes(List<String> uids);

  /// Guarda en usuarios/{uid} la facultad y el programa del estudiante.
  Future<void> asignarProgramaEstudiante({
    required String uid,
    required Facultad facultad,
    required Programa programa,
  });
}
