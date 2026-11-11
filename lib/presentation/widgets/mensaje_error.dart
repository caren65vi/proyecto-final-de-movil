import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Caja roja con un error del formulario que no pertenece a un solo campo
/// (credenciales incorrectas, sin conexión, falta el horario...).
/// Se pone junto al botón de enviar.
class MensajeError extends StatelessWidget {
  const MensajeError({super.key, required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.errorContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 18,
              color: AppColors.error,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                texto,
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Texto rojo pequeño bajo un control que no es un TextFormField
/// (casilla de términos, horario, ubicación...), igual al de los campos.
class ErrorDeCampo extends StatelessWidget {
  const ErrorDeCampo({super.key, required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 12),
      child: Text(
        texto,
        style: TextStyle(
          color: Theme.of(context).colorScheme.error,
          fontSize: 12,
        ),
      ),
    );
  }
}
