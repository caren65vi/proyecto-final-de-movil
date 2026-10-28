import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'FireBase/firebase_options.dart';
import 'data/datasources/auth_datasource.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'domain/usecases/auth_usecases.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const CeibaApp());
}

class CeibaApp extends StatelessWidget {
  const CeibaApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Se arman las capas: datasource → repositorio → caso de uso → pantalla
    final authRepository = AuthRepositoryImpl(AuthDatasource());

    return MaterialApp(
      title: 'Ceiba',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // Calendarios, selectores de hora y demás textos de Flutter en español
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: LoginScreen(
        iniciarSesion: IniciarSesion(authRepository),
        registrarUsuario: RegistrarUsuario(authRepository),
        recuperarContrasena: RecuperarContrasena(authRepository),
        enviarCorreoVerificacion: EnviarCorreoVerificacion(authRepository),
        comprobarCorreoVerificado: ComprobarCorreoVerificado(authRepository),
        cerrarSesion: CerrarSesion(authRepository),
      ),
    );
  }
}
