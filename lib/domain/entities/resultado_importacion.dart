import 'estudiante_inscrito.dart';

/// Resultado de leer el archivo de la lista de estudiantes.
class ResultadoImportacion {
  final String nombreArchivo;
  final List<EstudianteInscrito> estudiantes;

  /// Filas que no se cargaron y por qué (ej. fila 7: "correo no válido").
  /// El número es el de la fila en Excel (la de títulos es la 1).
  final List<({int fila, String motivo})> omitidas;

  const ResultadoImportacion({
    required this.nombreArchivo,
    required this.estudiantes,
    this.omitidas = const [],
  });
}
