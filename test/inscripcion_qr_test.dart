import 'package:flutter_test/flutter_test.dart';

import 'package:ceiba/domain/entities/materia_estudiante.dart';
import 'package:ceiba/domain/repositories/asistencia_repository.dart';
import 'package:ceiba/domain/repositories/curso_repository.dart';
import 'package:ceiba/domain/repositories/inscripcion_repository.dart';
import 'package:ceiba/domain/usecases/asistencia_usecases.dart';
import 'package:ceiba/domain/usecases/curso_usecases.dart';
import 'package:ceiba/domain/usecases/inscripcion_usecases.dart';

/// Guarda con qué datos se llamó al servidor.
class _RepoInscripcion implements InscripcionRepository {
  String? grupoId;
  String? token;

  @override
  Future<String> inscribirseConQR({
    required String grupoId,
    required String token,
  }) async {
    this.grupoId = grupoId;
    this.token = token;
    return 'Cálculo I';
  }

  @override
  Stream<List<MateriaEstudiante>> misMaterias(String correo) =>
      Stream.value(const []);

  @override
  Future<void> enlazarCuenta(String correo, String uid) async {}
}

class _RepoAsistencia implements AsistenciaRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('No debería llamarse');
}

void main() {
  group('InscribirseConQR', () {
    test('lee el curso y el token del QR del docente', () async {
      final repo = _RepoInscripcion();
      final contenido = InscripcionQR.contenido('grupo1', 'abc123');

      final materia = await InscribirseConQR(repo)(contenido);

      expect(materia, 'Cálculo I');
      expect(repo.grupoId, 'grupo1');
      expect(repo.token, 'abc123');
    });

    test('rechaza el QR de asistencia', () {
      final contenido = RegistrarAsistenciaQR.contenido('g', 's', 't');
      expect(
        () => InscribirseConQR(_RepoInscripcion())(contenido),
        throwsA(
          isA<CursoError>().having(
            (e) => e.mensaje,
            'mensaje',
            contains('registrar asistencia'),
          ),
        ),
      );
    });

    test('rechaza un QR que no es de Ceiba', () {
      expect(
        () => InscribirseConQR(_RepoInscripcion())('https://ejemplo.com'),
        throwsA(isA<CursoError>()),
      );
    });
  });

  test(
    'El escáner de asistencia avisa si le muestran el QR de inscripción',
    () {
      final contenido = InscripcionQR.contenido('grupo1', 'abc123');
      expect(
        () => RegistrarAsistenciaQR(_RepoAsistencia())(contenido),
        throwsA(
          isA<AsistenciaError>().having(
            (e) => e.mensaje,
            'mensaje',
            contains('inscribirse'),
          ),
        ),
      );
    },
  );
}
