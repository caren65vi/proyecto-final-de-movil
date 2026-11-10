import 'package:flutter_test/flutter_test.dart';

import 'package:ceiba/domain/entities/facultad.dart';
import 'package:ceiba/domain/entities/programa.dart';
import 'package:ceiba/domain/repositories/facultad_repository.dart';
import 'package:ceiba/domain/usecases/facultad_usecases.dart';

import 'widget_test.dart' show FakeFacultadRepository;

/// Repositorio falso que recuerda lo que se le pide.
class _Repositorio extends FakeFacultadRepository {
  int programasDeLaFacultad = 0;
  bool facultadEliminada = false;
  String? programaGuardado;

  @override
  Future<int> contarProgramas(String facultadId) async => programasDeLaFacultad;

  @override
  Future<void> eliminarFacultad(String id) async => facultadEliminada = true;

  @override
  Future<void> asignarProgramaEstudiante({
    required String uid,
    required Facultad facultad,
    required Programa programa,
  }) async => programaGuardado = programa.id;
}

void main() {
  late _Repositorio repo;
  setUp(() => repo = _Repositorio());

  const ingenieria = Facultad(
    id: 'ingenieria',
    nombre: 'Ingeniería',
    creadaPor: 'd1',
  );
  const sistemas = Programa(
    id: 'ingenieria-de-sistemas',
    facultadId: 'ingenieria',
    nombre: 'Ingeniería de Sistemas',
    creadaPor: 'd1',
  );
  const medicina = Programa(
    id: 'medicina',
    facultadId: 'salud',
    nombre: 'Medicina',
    creadaPor: 'd1',
  );

  test('el ID del programa no depende de tildes ni mayúsculas', () async {
    final p = await CrearPrograma(repo)(
      'ingenieria',
      '  Ingeniería   de SISTEMAS ',
      'd1',
    );
    expect(p.nombre, 'Ingeniería de SISTEMAS');
    expect(p.id, 'ingenieria-de-sistemas');
    expect(p.facultadId, 'ingenieria');
  });

  test('no deja crear un programa sin nombre', () {
    expect(
      CrearPrograma(repo)('ingenieria', '   ', 'd1'),
      throwsA(isA<FacultadError>()),
    );
  });

  test('no deja borrar una facultad que tiene programas', () async {
    repo.programasDeLaFacultad = 2;
    await expectLater(
      EliminarFacultad(repo)('ingenieria'),
      throwsA(isA<FacultadError>()),
    );
    expect(repo.facultadEliminada, isFalse);
  });

  test('borra la facultad si ya no tiene programas', () async {
    await EliminarFacultad(repo)('ingenieria');
    expect(repo.facultadEliminada, isTrue);
  });

  test('el estudiante guarda un programa de su facultad', () async {
    await AsignarProgramaEstudiante(repo)(
      uid: 'e1',
      facultad: ingenieria,
      programa: sistemas,
    );
    expect(repo.programaGuardado, 'ingenieria-de-sistemas');
  });

  test('rechaza un programa que no es de la facultad elegida', () async {
    await expectLater(
      AsignarProgramaEstudiante(repo)(
        uid: 'e1',
        facultad: ingenieria,
        programa: medicina,
      ),
      throwsA(isA<FacultadError>()),
    );
    expect(repo.programaGuardado, isNull);
  });
}
