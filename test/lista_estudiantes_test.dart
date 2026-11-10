import 'package:flutter_test/flutter_test.dart';

import 'package:ceiba/data/datasources/lista_estudiantes_datasource.dart';
import 'package:ceiba/domain/repositories/curso_repository.dart';

void main() {
  const leer = ListaEstudiantesDatasource.leerFilas;

  // Igual que el Excel de la universidad (el programa con salto de línea
  // y el código como número de Excel)
  const titulos = [
    'PROGRAMA',
    'CODIGOESTUDIANTE',
    'MAIL_INST',
    'NOMBRECOMPLETO',
  ];

  test('lee el formato de la universidad', () {
    final r = leer([
      titulos,
      [
        'INGENIERIA DE\nSISTEMAS',
        '4245172970.0',
        'laur.alvarez@udla.edu.co',
        'Alvarez Rojas Laura Camila',
      ],
      [
        'INGENIERIA DE SISTEMAS',
        '4282805612',
        'AND.ARAQUE@udla.edu.co',
        'Araque Suarez Andres Camilo',
      ],
    ]);
    expect(r.estudiantes, hasLength(2));
    expect(r.omitidas, isEmpty);
    final laura = r.estudiantes.first;
    expect(laura.correo, 'laur.alvarez@udla.edu.co');
    expect(laura.nombre, 'Alvarez Rojas Laura Camila');
    expect(laura.codigoEstudiante, '4245172970'); // sin ".0"
    expect(r.estudiantes[1].correo, 'and.araque@udla.edu.co'); // minúscula
  });

  test('dice qué filas omitió y por qué', () {
    final r = leer([
      titulos,
      ['SIS', '1', 'buena@udla.edu.co', 'Buena'],
      ['SIS', '2', '', 'Sin correo'],
      ['SIS', '3', 'mal-escrito', 'Mal'],
      ['SIS', '4', 'buena@udla.edu.co', 'Repetida'],
      ['', '', '', ''], // vacía: se ignora sin avisar
    ]);
    expect(r.estudiantes, hasLength(1));
    expect(r.omitidas.map((o) => o.fila), [3, 4, 5]);
    expect(r.omitidas[0].motivo, contains('no tiene correo'));
    expect(r.omitidas[1].motivo, contains('no válido'));
    expect(r.omitidas[2].motivo, contains('repetido'));
  });

  test('error claro si falta la columna del correo', () {
    expect(
      () => leer([
        ['PROGRAMA', 'CODIGOESTUDIANTE', 'NOMBRECOMPLETO'],
        ['SIS', '1', 'Laura'],
      ]),
      throwsA(
        isA<CursoError>().having(
          (e) => e.mensaje,
          'mensaje',
          allOf(contains('MAIL_INST'), contains('Columnas encontradas')),
        ),
      ),
    );
  });

  test('error si falta la columna del nombre', () {
    expect(
      () => leer([
        ['MAIL_INST'],
        ['laura@udla.edu.co'],
      ]),
      throwsA(
        isA<CursoError>().having(
          (e) => e.mensaje,
          'mensaje',
          contains('NOMBRECOMPLETO'),
        ),
      ),
    );
  });

  test('error si el archivo está vacío o sin correos válidos', () {
    expect(() => leer([]), throwsA(isA<CursoError>()));
    expect(
      () => leer([
        titulos,
        ['SIS', '1', 'sin-arroba', 'Laura'],
      ]),
      throwsA(isA<CursoError>()),
    );
  });

  test('acepta los títulos anteriores (correo, nombre, codigo)', () {
    final r = leer([
      ['Nombre', 'Correo', 'Código'],
      ['Laura', 'laura@udla.edu.co', '123'],
    ]);
    expect(r.estudiantes.single.codigoEstudiante, '123');
  });
}
