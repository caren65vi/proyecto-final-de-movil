/// Facultad o carrera a la que pertenece un curso.
/// Se guarda en la colección "facultades" y la comparten todos los docentes.
class Facultad {
  final String id;
  final String nombre;
  final String creadaPor; // uid del docente que la creó

  const Facultad({
    required this.id,
    required this.nombre,
    required this.creadaPor,
  });

  /// ID a partir del nombre, sin tildes ni mayúsculas, para que
  /// "Ingeniería" e "ingenieria" sean la misma facultad.
  /// Ej. "Facultad de Ingeniería" → "facultad-de-ingenieria".
  static String idDesde(String nombre) {
    const conTilde = 'áéíóúüñàèìòù';
    const sinTilde = 'aeiouunaeiou';
    var texto = nombre.toLowerCase();
    for (var i = 0; i < conTilde.length; i++) {
      texto = texto.replaceAll(conTilde[i], sinTilde[i]);
    }
    return texto
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }
}
