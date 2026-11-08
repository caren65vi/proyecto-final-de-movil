import 'package:flutter/material.dart';

import '../domain/entities/usuario.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/curso_repository.dart';
import '../domain/repositories/inscripcion_repository.dart';
import '../domain/usecases/auth_usecases.dart';
import '../domain/usecases/curso_usecases.dart';
import '../domain/usecases/inscripcion_usecases.dart';
import '../presentation/screens/Docente/crear_curso.dart';
import '../presentation/screens/Docente/home_docente.dart';
import '../presentation/screens/Estudiante/home_estudiante.dart';
import '../presentation/screens/auth/login_screen.dart';
import '../presentation/screens/auth/recover_password_screen.dart';
import '../presentation/screens/auth/register_screen.dart';
import '../presentation/screens/auth/verify_email_screen.dart';
import '../presentation/screens/Docente/detalle_curso.dart';
import '../presentation/screens/Docente/editar_curso.dart';
import '../domain/entities/curso.dart';

/// Rutas de la aplicación.
///
/// Aquí están los nombres de todas las pantallas y cómo se construyen:
/// las pantallas solo navegan por nombre (`Navigator.pushNamed`) y esta clase
/// les entrega los casos de uso y repositorios que necesitan.
class AppRoutes {
  AppRoutes({
    required this.authRepository,
    required this.cursoRepository,
    required this.inscripcionRepository,
  });

  final AuthRepository authRepository;
  final CursoRepository cursoRepository;
  final InscripcionRepository inscripcionRepository;

  // ---------- Nombres de las rutas ----------

  /// Pantalla inicial.
  static const String login = '/';
  static const String registro = '/registro';

  /// Argumento opcional: `String` con el correo para precargar.
  static const String recuperarContrasena = '/recuperar-contrasena';

  /// Argumento: `String` con el correo a verificar.
  static const String verificarCorreo = '/verificar-correo';

  /// Argumento: `Usuario` que inició sesión.
  static const String homeDocente = '/docente';

  /// Argumento: `Usuario` (docente) que crea el curso.
  /// Al guardar, la pantalla devuelve `true`.
  static const String crearCurso = '/docente/crear-curso';

  /// Argumento: `Usuario` que inició sesión.
  static const String homeEstudiante = '/estudiante';

  /// Argumento: `String` con el ID del grupo y `CursoRepository`.
  static const String detalleCurso = '/docente/detalle-curso';

  ///argumento : para editar del curso
  static const String editarCurso = '/docente/editar-curso';

  // ---------- Construcción de las pantallas ----------

  /// Se usa en `MaterialApp.onGenerateRoute`.
  Route<dynamic> generarRuta(RouteSettings settings) {
    final args = settings.arguments;

    final Widget pantalla = switch (settings.name) {
      login => LoginScreen(iniciarSesion: IniciarSesion(authRepository)),
      registro => RegisterScreen(
        registrarUsuario: RegistrarUsuario(authRepository),
      ),
      recuperarContrasena => RecoverPasswordScreen(
        recuperarContrasena: RecuperarContrasena(authRepository),
        correoInicial: args is String ? args : '',
      ),
      verificarCorreo when args is String => VerifyEmailScreen(
        email: args,
        enviarCorreoVerificacion: EnviarCorreoVerificacion(authRepository),
        comprobarCorreoVerificado: ComprobarCorreoVerificado(authRepository),
        cerrarSesion: CerrarSesion(authRepository),
      ),
      verificarCorreo => _RutaNoEncontrada(nombre: settings.name),
      homeDocente when args is Usuario => HomeDocenteScreen(
        usuario: args,
        cerrarSesion: CerrarSesion(authRepository),
        obtenerMisCursos: ObtenerMisCursos(cursoRepository),
      ),
      homeDocente => _RutaNoEncontrada(nombre: settings.name),
      crearCurso when args is Usuario => CrearCursoScreen(
        usuario: args,
        cursoRepository: cursoRepository,
      ),
      crearCurso => _RutaNoEncontrada(nombre: settings.name),
      detalleCurso => DetalleCursoScreen(
        grupoId: args is String ? args : '',
        cursoRepository: cursoRepository,
      ),
      editarCurso when args is Curso => EditarCursoScreen(
        curso: args,
        editarCurso: EditarCurso(cursoRepository),
        importarEstudiantes: ImportarEstudiantes(cursoRepository),
        agregarEstudiante: AgregarEstudiante(cursoRepository),
      ),
      editarCurso => _RutaNoEncontrada(nombre: settings.name),
      homeEstudiante when args is Usuario => HomeEstudianteScreen(
        usuario: args,
        cerrarSesion: CerrarSesion(authRepository),
        obtenerMisMaterias: ObtenerMisMaterias(inscripcionRepository),
        enlazarCuenta: EnlazarCuenta(inscripcionRepository),
      ),
      homeEstudiante => _RutaNoEncontrada(nombre: settings.name),
      _ => _RutaNoEncontrada(nombre: settings.name),
    };

    return MaterialPageRoute(settings: settings, builder: (_) => pantalla);
  }

  /// Ruta de inicio según el rol del usuario.
  static String homeDe(Usuario usuario) =>
      usuario.esDocente ? homeDocente : homeEstudiante;
}

/// Se muestra si se navega a un nombre que no está registrado.
class _RutaNoEncontrada extends StatelessWidget {
  const _RutaNoEncontrada({required this.nombre});

  final String? nombre;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(child: Text('No existe la ruta "$nombre"')),
    );
  }
}
