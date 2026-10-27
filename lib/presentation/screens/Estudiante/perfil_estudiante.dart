import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/entities/usuario.dart';
import '../../theme/app_colors.dart';

// Tonos del diseño que no están en AppColors
const Color _errorContainer = Color(0xFFFFDAD6);
const Color _onErrorContainer = Color(0xFF93000A);

/// Pestaña de perfil del estudiante: identidad, correo y cierre de sesión.
class PerfilEstudiante extends StatelessWidget {
  const PerfilEstudiante({
    super.key,
    required this.usuario,
    required this.onCerrarSesion,
  });

  final Usuario usuario;
  final VoidCallback onCerrarSesion;

  // Iniciales del nombre para el avatar (ej. "Camilo Torres" → "CT")
  String get _iniciales {
    final partes = usuario.nombre.trim().split(RegExp(r'\s+'));
    return partes
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
  }

  void _copiarCorreo(BuildContext context) {
    Clipboard.setData(ClipboardData(text: usuario.correo));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Correo copiado')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        // Tarjeta de identidad
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Arco decorativo
              Positioned(
                top: -48,
                right: -48,
                child: Container(
                  width: 144,
                  height: 144,
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: AppColors.primaryFixed,
                          child: Text(
                            _iniciales,
                            style: const TextStyle(
                              color: AppColors.primaryDark,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Positioned(
                          right: -4,
                          bottom: -4,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryDark,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.verified,
                              size: 15,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        usuario.nombre,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Información académica
        const Text(
          'Información Académica',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.alternate_email,
                  size: 20,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Correo Institucional',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      usuario.correo,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Copiar correo',
                onPressed: () => _copiarCorreo(context),
                color: AppColors.outline,
                icon: const Icon(Icons.content_copy, size: 18),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Cierre de sesión
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _errorContainer,
              foregroundColor: _onErrorContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: onCerrarSesion,
            icon: const Icon(Icons.logout, size: 20),
            label: const Text('Cerrar Sesión'),
          ),
        ),
      ],
    );
  }
}
