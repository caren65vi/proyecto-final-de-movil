class Asistencia {
  final String correo;
  final String nombre;
  final String estado;
  final double horas;
  final String metodo;
  final DateTime? registradaEn;
  final String? justificacion;

  const Asistencia({
    required this.correo,
    required this.nombre,
    required this.estado,
    required this.horas,
    required this.metodo,
    this.registradaEn,
    this.justificacion,
  });

  bool get presente => estado == 'presente';
}
