import 'package:flutter_test/flutter_test.dart';

import 'package:ceiba/domain/entities/bloque_horario.dart';
import 'package:ceiba/domain/entities/curso.dart';
import 'package:ceiba/domain/entities/recuperacion.dart';
import 'package:ceiba/domain/repositories/curso_repository.dart';
import 'package:ceiba/domain/usecases/curso_usecases.dart';

import 'widget_test.dart' show FakeCursoRepository;

/// Guarda la última recuperación programada para revisarla en la prueba.
class _RepositorioQueGuarda extends FakeCursoRepository {
  Recuperacion? guardada;

  @override
  Future<void> programarRecuperacion(
    String grupoId,
    Recuperacion recuperacion,
    String docenteUid,
  ) async => guardada = recuperacion;
}

void main() {
  final hoy = DateTime.now();
  final manana = DateTime(hoy.year, hoy.month, hoy.day + 1);

  // Curso vigente con clase normal todos los días de mañana de 08:00 a 10:00
  Curso curso({DateTime? fin}) => Curso(
    id: 'grupo-1',
    nombreMateria: 'Cálculo',
    facultad: 'Ingeniería',
    numeroGrupo: '1',
    aula: '204',
    docenteUid: 'docente-1',
    docenteNombre: 'Docente',
    fechaInicio: DateTime(hoy.year, hoy.month, hoy.day - 30),
    fechaFin: fin ?? DateTime(hoy.year, hoy.month, hoy.day + 30),
    horario: [
      BloqueHorario(dia: manana.weekday, inicio: '08:00', fin: '10:00'),
    ],
    latitud: 1,
    longitud: 1,
    radioMetros: 50,
  );

  late _RepositorioQueGuarda repo;
  late ProgramarRecuperacion programar;

  setUp(() {
    repo = _RepositorioQueGuarda();
    programar = ProgramarRecuperacion(repo);
  });

  Future<void> programarEn(
    String inicio,
    String fin, {
    DateTime? fecha,
    Curso? enCurso,
  }) => programar(
    enCurso ?? curso(),
    Recuperacion(fecha: fecha ?? manana, inicio: inicio, fin: fin),
    'docente-1',
  );

  test('acepta una recuperación válida fuera del horario normal', () async {
    await programarEn('14:00', '16:00');
    expect(repo.guardada?.inicio, '14:00');
    expect(repo.guardada?.horas, 2);
  });

  test('rechaza si se cruza con la clase normal', () {
    expect(programarEn('09:00', '11:00'), throwsA(isA<CursoError>()));
  });

  test('rechaza si el fin es antes del inicio', () {
    expect(programarEn('16:00', '14:00'), throwsA(isA<CursoError>()));
  });

  test('rechaza fechas fuera del período del curso', () {
    expect(
      programarEn('14:00', '16:00', enCurso: curso(fin: hoy)),
      throwsA(isA<CursoError>()),
    );
  });

  test('rechaza fechas que ya pasaron', () {
    final ayer = DateTime(hoy.year, hoy.month, hoy.day - 1);
    expect(
      programarEn('14:00', '16:00', fecha: ayer),
      throwsA(isA<CursoError>()),
    );
  });

  test('solo está disponible desde 15 min antes hasta que termina', () {
    final r = Recuperacion(fecha: manana, inicio: '14:00', fin: '16:00');
    DateTime a(int h, int m) =>
        DateTime(manana.year, manana.month, manana.day, h, m);
    expect(r.disponible(a(13, 40)), isFalse);
    expect(r.disponible(a(13, 45)), isTrue);
    expect(r.disponible(a(15, 59)), isTrue);
    expect(r.disponible(a(16, 1)), isFalse);
  });
}
