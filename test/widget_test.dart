import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ceiba/domain/entities/asistencia.dart';
import 'package:ceiba/domain/entities/curso.dart';
import 'package:ceiba/domain/entities/estudiante_inscrito.dart';
import 'package:ceiba/domain/entities/materia_estudiante.dart';
import 'package:ceiba/domain/entities/usuario.dart';
import 'package:ceiba/domain/repositories/asistencia_repository.dart';
import 'package:ceiba/domain/repositories/auth_repository.dart';
import 'package:ceiba/domain/repositories/curso_repository.dart';
import 'package:ceiba/domain/repositories/inscripcion_repository.dart';
import 'package:ceiba/routes/app_routes.dart';

/// Repositorio falso: permite probar la pantalla sin conectarse a Firebase.
class FakeAuthRepository implements AuthRepository {
  @override
  Future<Usuario> iniciarSesion(String correo, String contrasena) async {
    if (contrasena != '123456') {
      throw const AuthError('Correo o contraseña incorrectos');
    }
    return Usuario(
      uid: 'abc',
      nombre: 'Caren',
      correo: correo,
      rol: 'docente',
      fechaCreacion: DateTime(2026, 10, 5),
    );
  }

  @override
  Future<Usuario> registrar({
    required String nombre,
    required String correo,
    required String contrasena,
    required String rol,
  }) => throw UnimplementedError();

  @override
  Future<Usuario?> obtenerUsuarioActual() async => null;

  @override
  Future<void> recuperarContrasena(String correo) async {}

  @override
  Future<int> enviarCodigoVerificacion() async => 60;

  @override
  Future<void> verificarCodigo(String codigo) async {
    if (codigo != '123456') {
      throw const AuthError('Código incorrecto. Te quedan 4 intentos.');
    }
  }

  @override
  Future<bool> correoVerificado() async => true;

  @override
  Future<void> cerrarSesion() async {}
}

/// Repositorio de cursos falso: las pruebas del login no lo usan.
class FakeCursoRepository implements CursoRepository {
  @override
  Future<String> crearCurso(
    Curso curso,
    List<EstudianteInscrito> estudiantes,
  ) async => 'curso-prueba';

  @override
  Stream<List<Curso>> misCursos(String docenteUid) => Stream.value(const []);

  @override
  Stream<Curso> curso(String grupoId) => throw UnimplementedError();

  @override
  Stream<List<EstudianteInscrito>> estudiantes(String grupoId) =>
      throw UnimplementedError();

  @override
  Future<void> editarCurso(Curso curso) => throw UnimplementedError();

  @override
  Future<void> agregarEstudiante(
    String grupoId,
    EstudianteInscrito estudiante,
  ) => throw UnimplementedError();

  @override
  Future<void> quitarEstudiante(String grupoId, String correo) =>
      throw UnimplementedError();

  @override
  Future<({double latitud, double longitud})> obtenerUbicacionActual() async =>
      (latitud: 1.619816, longitud: -75.604029);

  @override
  Future<({String nombreArchivo, List<EstudianteInscrito> estudiantes})?>
  importarEstudiantes() async => null;
}

class FakeInscripcionRepository implements InscripcionRepository {
  @override
  Stream<List<MateriaEstudiante>> misMaterias(String correo) =>
      Stream.value(const []);

  @override
  Future<void> enlazarCuenta(String correo, String uid) async {}
}

class FakeAsistenciaRepository implements AsistenciaRepository {
  @override
  Future<({String sesionId, String token})> abrirSesion(String grupoId) async =>
      (sesionId: 'sesion-prueba', token: 'token-prueba');

  @override
  Future<String> renovarQR(String grupoId, String sesionId) async =>
      'token-nuevo';

  @override
  Future<void> cerrarSesion(String grupoId, String sesionId) async {}

  @override
  Future<void> registrarAsistencia({
    required String grupoId,
    required String sesionId,
    required String token,
  }) async {}

  @override
  Stream<List<Asistencia>> asistencias(String grupoId, String sesionId) =>
      Stream.value(const []);

  @override
  Stream<String> tokenQR(String grupoId, String sesionId) =>
      Stream.value('token-prueba');
}

Future<void> abrirLogin(WidgetTester tester) {
  final rutas = AppRoutes(
    authRepository: FakeAuthRepository(),
    cursoRepository: FakeCursoRepository(),
    inscripcionRepository: FakeInscripcionRepository(),
    asistenciaRepository: FakeAsistenciaRepository(),
  );
  return tester.pumpWidget(
    MaterialApp(
      initialRoute: AppRoutes.login,
      onGenerateRoute: rutas.generarRuta,
    ),
  );
}

void main() {
  testWidgets('La pantalla de carga sigue al login si no hay sesión', (
    tester,
  ) async {
    final rutas = AppRoutes(
      authRepository: FakeAuthRepository(),
      cursoRepository: FakeCursoRepository(),
      inscripcionRepository: FakeInscripcionRepository(),
      asistenciaRepository: FakeAsistenciaRepository(),
    );
    await tester.pumpWidget(
      MaterialApp(
        onGenerateInitialRoutes: (_) => [
          rutas.generarRuta(const RouteSettings(name: AppRoutes.carga)),
        ],
        onGenerateRoute: rutas.generarRuta,
      ),
    );

    expect(find.text('Ceiba'), findsOneWidget);

    // Las animaciones son infinitas: se avanza el reloj en vez de pumpAndSettle
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Ceiba'), findsNothing);
    expect(find.text('Iniciar sesión'), findsWidgets);
  });

  group('Verificación por código', () {
    Future<void> abrirVerificacion(WidgetTester tester) {
      final rutas = AppRoutes(
        authRepository: FakeAuthRepository(),
        cursoRepository: FakeCursoRepository(),
        inscripcionRepository: FakeInscripcionRepository(),
        asistenciaRepository: FakeAsistenciaRepository(),
      );
      // El login queda debajo, como cuando se llega desde el registro
      return tester.pumpWidget(
        MaterialApp(
          onGenerateInitialRoutes: (_) => [
            rutas.generarRuta(const RouteSettings(name: AppRoutes.login)),
            rutas.generarRuta(
              const RouteSettings(
                name: AppRoutes.verificarCorreo,
                arguments: 'caren@udla.edu.co',
              ),
            ),
          ],
          onGenerateRoute: rutas.generarRuta,
        ),
      );
    }

    testWidgets('Envía el código al abrir y muestra el vencimiento', (
      tester,
    ) async {
      await abrirVerificacion(tester);
      await tester.pump();

      expect(find.text('Verifica tu correo'), findsOneWidget);
      expect(find.textContaining('Expira en 09:5'), findsOneWidget);
      expect(find.textContaining('Solicitar nuevo código ('), findsOneWidget);

      // Se quita la pantalla para cancelar su reloj
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Un código incorrecto muestra el error', (tester) async {
      await abrirVerificacion(tester);
      await tester.pump();

      await tester.enterText(find.byType(TextField), '111111');
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Código incorrecto. Te quedan 4 intentos.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('El código correcto vuelve al login', (tester) async {
      await abrirVerificacion(tester);
      await tester.pump();

      await tester.enterText(find.byType(TextField), '123456');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Verifica tu correo'), findsNothing);
      expect(
        find.text('Correo verificado. Ya puedes iniciar sesión.'),
        findsOneWidget,
      );
    });
  });

  testWidgets('Muestra errores si los campos están vacíos', (tester) async {
    await abrirLogin(tester);

    await tester.tap(find.text('Iniciar sesión').last);
    await tester.pump();

    expect(find.text('Ingresa tu correo institucional'), findsOneWidget);
    expect(find.text('Ingresa tu contraseña'), findsOneWidget);
  });

  testWidgets('Muestra el mensaje de error de AuthError', (tester) async {
    await abrirLogin(tester);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'caren@udla.edu.co',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'clave-mala');
    await tester.tap(find.text('Iniciar sesión').last);
    await tester.pumpAndSettle();

    expect(find.text('Correo o contraseña incorrectos'), findsOneWidget);
  });

  testWidgets('Da la bienvenida con nombre y rol al iniciar sesión', (
    tester,
  ) async {
    await abrirLogin(tester);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'caren@udla.edu.co',
    );
    await tester.enterText(find.byType(TextFormField).at(1), '123456');
    await tester.tap(find.text('Iniciar sesión').last);
    await tester.pumpAndSettle();

    // Tras el login el docente llega a su pantalla de inicio
    expect(find.text('Hola, Prof. Caren'), findsOneWidget);
  });
}
