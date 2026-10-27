import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Pestaña de estadísticas del docente: rendimiento de asistencia por materia.
class EstadisticasDocente extends StatelessWidget {
  const EstadisticasDocente({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: const [
        Text(
          'Rendimiento de Asistencia',
          style: TextStyle(
            color: AppColors.primaryDark,
            fontSize: 26,
            height: 1.3,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.26,
          ),
        ),

        SizedBox(height: 24),

        // Asistencia por materia
        Text(
          'Asistencia por Materia',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
