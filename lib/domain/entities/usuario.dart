class Usuario {
  final String uid;
  final String nombre;
  final String correo;
  final String rol; // "docente" o "estudiante"
  final DateTime fechaCreacion;

  const Usuario({
    required this.uid,
    required this.nombre,
    required this.correo,
    required this.rol,
    required this.fechaCreacion,
  });

  bool get esDocente => rol == 'docente';
  bool get esEstudiante => rol == 'estudiante';
}
