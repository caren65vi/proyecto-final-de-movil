import 'package:flutter/material.dart';

import '../../domain/entities/usuario.dart';

/// Pantalla de bienvenida que se abre al iniciar sesión.
class PortalScreen extends StatelessWidget {
  const PortalScreen({super.key, required this.usuario});

  final Usuario usuario;

  static const Color _azul = Color(0xFF1565C0);

  @override
  Widget build(BuildContext context) {
    // El saludo cambia según el rol de quien inicia sesión
    final saludo = usuario.esDocente ? 'Bienvenido docente' : 'Bienvenido estudiante';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _azul, width: 2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    saludo,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _azul,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    usuario.nombre,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _azul,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
