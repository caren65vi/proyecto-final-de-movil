import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'FireBase/firebase_options.dart';
import 'data/datasources/asistencia_datasource.dart';
import 'data/datasources/auth_datasource.dart';
import 'data/datasources/curso_datasource.dart';
import 'data/datasources/facultad_datasource.dart';
import 'data/datasources/inscripcion_datasource.dart';
import 'data/datasources/lista_estudiantes_datasource.dart';
import 'data/datasources/ubicacion_datasource.dart';
import 'data/repositories/asistencia_repository_impl.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'data/repositories/curso_repository_impl.dart';
import 'data/repositories/facultad_repository_impl.dart';
import 'data/repositories/inscripcion_repository_impl.dart';
import 'presentation/theme/app_theme.dart';
import 'routes/app_routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const CeibaApp());
}

class CeibaApp extends StatelessWidget {
  const CeibaApp({super.key});

  @override
  Widget build(BuildContext context) {
    
    // Se arman las capas: datasource → repositorio → rutas → pantallas
    final authRepository = AuthRepositoryImpl(AuthDatasource());
    final cursoRepository = CursoRepositoryImpl(
      cursoDatasource: CursoDatasource(),
      ubicacionDatasource: UbicacionDatasource(),
      listaDatasource: ListaEstudiantesDatasource(),
    );

    final inscripcionRepository = InscripcionRepositoryImpl(
      InscripcionDatasource(),
    );
    final asistenciaRepository = AsistenciaRepositoryImpl(
      datasource: AsistenciaDatasource(),
      ubicacionDatasource: UbicacionDatasource(),
    );
    final facultadRepository = FacultadRepositoryImpl(FacultadDatasource());
    final rutas = AppRoutes(
      authRepository: authRepository,
      cursoRepository: cursoRepository,
      inscripcionRepository: inscripcionRepository,
      asistenciaRepository: asistenciaRepository,
      facultadRepository: facultadRepository,
    );

    return MaterialApp(
      title: 'Ceiba',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // Calendarios, selectores de hora y demás textos de Flutter en español
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // Solo la pantalla de carga (con initialRoute Flutter apilaría
      // también '/' debajo); ella decide si sigue al login o al inicio.
      onGenerateInitialRoutes: (_) => [
        rutas.generarRuta(const RouteSettings(name: AppRoutes.carga)),
      ],
      onGenerateRoute: rutas.generarRuta,
    );
  }
}
