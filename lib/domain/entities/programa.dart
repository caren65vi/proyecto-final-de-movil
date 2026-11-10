/// Programa académico (carrera) que pertenece a una facultad.
/// Se guarda en facultades/{facultadId}/programas/{id}.
class Programa {
  final String id;
  final String facultadId;
  final String nombre;
  final String creadaPor; // uid del docente que lo creó

  const Programa({
    required this.id,
    required this.facultadId,
    required this.nombre,
    required this.creadaPor,
  });
}
