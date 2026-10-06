import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ceiba/domain/entities/usuario.dart';
import 'package:ceiba/domain/repositories/auth_repository.dart';
import 'package:ceiba/domain/usecases/auth_usecases.dart';
import 'package:ceiba/presentation/screens/auth/login_screen.dart';

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
  Future<void> cerrarSesion() async {}
}

Future<void> abrirLogin(WidgetTester tester) {
  final repository = FakeAuthRepository();
  return tester.pumpWidget(
    MaterialApp(
      home: LoginScreen(
        iniciarSesion: IniciarSesion(repository),
        registrarUsuario: RegistrarUsuario(repository),
        recuperarContrasena: RecuperarContrasena(repository),
      ),
    ),
  );
}

void main() {
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

    expect(find.text('Bienvenido, Caren (docente)'), findsOneWidget);
  });
}
