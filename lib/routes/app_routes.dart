import 'package:flutter/material.dart';

import '../domain/entities/usuario.dart';
import '../domain/repositories/asistencia_repository.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/curso_repository.dart';
import '../domain/repositories/facultad_repository.dart';
import '../domain/usecases/facultad_usecases.dart';
import '../presentation/screens/Docente/facultades_docente.dart';
import '../domain/repositories/inscripcion_repository.dart';
import '../domain/usecases/asistencia_usecases.dart';
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
import '../presentation/screens/Docente/asistencia_qr.dart';
import '../presentation/screens/Estudiante/escanear_qr.dart';
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
    required this.asistenciaRepository,
    required this.facultadRepository,
  });

  final AuthRepository authRepository;
  final CursoRepository cursoRepository;
  final InscripcionRepository inscripcionRepository;
  final AsistenciaRepository asistenciaRepository;
  final FacultadRepository facultadRepository;

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

  /// Argumento: el `Curso` del que se toma asistencia.
  static const String asistenciaQR = '/docente/asistencia';

  /// Argumento: `Usuario` (docente) que gestiona las facultades.
  static const String facultades = '/docente/facultades';

  /// Argumento opcional: `List<Curso>` del estudiante (para la clase en curso).
  static const String escanearQR = '/estudiante/escanear';

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
        obtenerTendenciaSemanal: ObtenerTendenciaSemanal(asistenciaRepository),
      ),
      homeDocente => _RutaNoEncontrada(nombre: settings.name),
      crearCurso when args is Usuario => CrearCursoScreen(
        usuario: args,
        cursoRepository: cursoRepository,
        obtenerFacultades: ObtenerFacultades(facultadRepository),
        crearFacultad: CrearFacultad(facultadRepository),
      ),
      crearCurso => _RutaNoEncontrada(nombre: settings.name),
      facultades when args is Usuario => FacultadesScreen(
        usuario: args,
        obtenerFacultades: ObtenerFacultades(facultadRepository),
        crearFacultad: CrearFacultad(facultadRepository),
        eliminarFacultad: EliminarFacultad(facultadRepository),
      ),
      facultades => _RutaNoEncontrada(nombre: settings.name),
      detalleCurso => DetalleCursoScreen(
        grupoId: args is String ? args : '',
        cursoRepository: cursoRepository,
      ),
      asistenciaQR when args is Curso => AsistenciaQrScreen(
        curso: args,
        asistenciaRepository: asistenciaRepository,
        cursoRepository: cursoRepository,
      ),
      asistenciaQR => _RutaNoEncontrada(nombre: settings.name),
      escanearQR => EscanearQrScreen(
        asistenciaRepository: asistenciaRepository,
        cursos: args is List<Curso> ? args : const [],
      ),
      editarCurso when args is Curso => EditarCursoScreen(
        curso: args,
        editarCurso: EditarCurso(cursoRepository),
        importarEstudiantes: ImportarEstudiantes(cursoRepository),
        agregarEstudiante: AgregarEstudiante(cursoRepository),
        obtenerMiUbicacion: ObtenerMiUbicacion(cursoRepository),
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
