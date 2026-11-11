import 'package:flutter_test/flutter_test.dart';

import 'package:ceiba/domain/entities/curso.dart';
import 'package:ceiba/domain/entities/estudiante_inscrito.dart';
import 'package:ceiba/domain/entities/materia_estudiante.dart';

void main() {
  MateriaEstudiante materia(String nombre, String profesor) =>
      MateriaEstudiante(
        curso: Curso(
          nombreMateria: nombre,
          facultad: 'Facultad de Ingeniería',
          numeroGrupo: '2',
          aula: 'Aula 204',
          docenteUid: 'd1',
          docenteNombre: profesor,
          fechaInicio: DateTime(2026, 8, 1),
          fechaFin: DateTime(2026, 12, 1),
          horario: const [],
          latitud: 1,
          longitud: 1,
          radioMetros: 50,
        ),
        inscripcion: const EstudianteInscrito(
          correo: 'e@udla.edu.co',
          nombre: 'E',
        ),
      );

  final calculo = materia('Cálculo Multivariado', 'Carlos Mendoza');
  final fisica = materia('Física Termodinámica', 'Elena Velásquez');

  test('busca por materia sin importar tildes ni mayúsculas', () {
    expect(calculo.coincideCon('calculo'), isTrue);
    expect(calculo.coincideCon('CÁLCULO'), isTrue);
    expect(fisica.coincideCon('termodinamica'), isTrue);
    expect(fisica.coincideCon('calculo'), isFalse);
  });

  test('busca por profesor', () {
    expect(fisica.coincideCon('velasquez'), isTrue);
    expect(calculo.coincideCon('carlos'), isTrue);
    expect(calculo.coincideCon('elena'), isFalse);
  });

  test('varias palabras en cualquier orden', () {
    expect(calculo.coincideCon('mendoza calculo'), isTrue);
    expect(calculo.coincideCon('  calculo   carlos '), isTrue);
    expect(calculo.coincideCon('calculo elena'), isFalse);
  });

  test('búsqueda vacía muestra todo', () {
    expect(calculo.coincideCon(''), isTrue);
    expect(calculo.coincideCon('   '), isTrue);
  });

  test('también encuentra por aula o facultad', () {
    expect(calculo.coincideCon('204'), isTrue);
    expect(calculo.coincideCon('ingenieria'), isTrue);
  });
}
