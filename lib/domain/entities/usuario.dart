class Usuario {
  final String uid;
  final String nombre;
  final String correo;
  final String rol; // "docente" o "estudiante"
  final DateTime fechaCreacion;

  // Facultad y programa del estudiante (null mientras no los elija).
  // Se guardan también los nombres para mostrarlos sin otra consulta.
  final String? facultadId;
  final String? facultadNombre;
  final String? programaId;
  final String? programaNombre;

  const Usuario({
    required this.uid,
    required this.nombre,
    required this.correo,
    required this.rol,
    required this.fechaCreacion,
    this.facultadId,
    this.facultadNombre,
    this.programaId,
    this.programaNombre,
  });

  bool get esDocente => rol == 'docente';
  bool get esEstudiante => rol == 'estudiante';
  bool get tienePrograma => facultadId != null && programaId != null;
}
