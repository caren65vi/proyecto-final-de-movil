import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/screens/login_screen.dart';

void main() {
  runApp(const CeibaApp());
}

class CeibaApp extends StatelessWidget {
  const CeibaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ceiba',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const LoginScreen(),
    );
  }
}
