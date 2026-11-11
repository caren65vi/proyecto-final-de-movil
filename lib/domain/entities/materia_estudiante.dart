import 'curso.dart';
import 'estudiante_inscrito.dart';

/// Una materia del estudiante: el curso y su inscripción (con sus horas).
class MateriaEstudiante {
  final Curso curso;
  final EstudianteInscrito inscripcion;

  const MateriaEstudiante({required this.curso, required this.inscripcion});

  /// La materia coincide con lo que el estudiante escribió en el buscador.
  /// No importan las tildes, las mayúsculas ni el orden de las palabras:
  /// "calculo mendoza" encuentra "Cálculo Multivariado" del "Prof. Carlos
  /// Mendoza". Busca en la materia, el profesor, la facultad y el aula.
  bool coincideCon(String busqueda) {
    final palabras = normalizar(busqueda)
        .split(' ')
        .where((p) => p.isNotEmpty)
        .toList();
    if (palabras.isEmpty) return true;
    final texto = normalizar(
      '${curso.nombreMateria} ${curso.docenteNombre} '
      '${curso.facultad} ${curso.aula}',
    );
    return palabras.every(texto.contains);
  }

  /// Minúsculas, sin tildes y con un solo espacio entre palabras.
  static String normalizar(String texto) {
    const conTilde = 'áéíóúüñàèìòù';
    const sinTilde = 'aeiouunaeiou';
    var t = texto.toLowerCase();
    for (var i = 0; i < conTilde.length; i++) {
      t = t.replaceAll(conTilde[i], sinTilde[i]);
    }
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
