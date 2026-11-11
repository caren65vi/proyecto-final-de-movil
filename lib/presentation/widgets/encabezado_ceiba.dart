import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Encabezado común del docente y del estudiante:
/// logo · "Ceiba" · "PORTAL DOCENTE"/"PORTAL ESTUDIANTE" · campana.
class EncabezadoCeiba extends StatelessWidget implements PreferredSizeWidget {
  const EncabezadoCeiba({
    super.key,
    required this.portal,
    this.onNotificaciones,
    this.hayNotificaciones = false,
  });

  /// Texto debajo de "Ceiba" (ej. "Portal Estudiante"); se muestra en
  /// mayúsculas.
  final String portal;

  /// Al tocar la campana. Si es null, la campana no se muestra.
  final VoidCallback? onNotificaciones;

  /// Muestra el punto rojo de la campana (hay notificaciones sin leer).
  final bool hayNotificaciones;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 64,
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: AppColors.primary.withValues(alpha: 0.08),
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      // Línea fina bajo el encabezado
      shape: const Border(
        bottom: BorderSide(color: AppColors.surfaceContainer),
      ),
      title: Row(
        children: [
          // El mismo logo y tamaño que tenía el encabezado antes
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/images/ceiba_logo.png',
              width: 36,
              height: 36,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ceiba',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              Text(
                portal.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        if (onNotificaciones != null)
          IconButton(
            tooltip: 'Notificaciones',
            onPressed: onNotificaciones,
            color: AppColors.textPrimary,
            icon: Badge(
              isLabelVisible: hayNotificaciones,
              smallSize: 8,
              backgroundColor: AppColors.error,
              child: const Icon(Icons.notifications_outlined, size: 24),
            ),
          ),
        const SizedBox(width: 8),
      ],
    );
  }
}
