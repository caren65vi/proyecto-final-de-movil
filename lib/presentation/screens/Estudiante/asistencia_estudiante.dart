import 'package:flutter/material.dart';

/// Pestaña de asistencia del estudiante: progreso de asistencia por materia.
class AsistenciaEstudiante extends StatelessWidget {
  const AsistenciaEstudiante({super.key, required this.onEscanear});

  final VoidCallback onEscanear;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        const Text(
          'Registra tu asistencia',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text('Escanea el código QR que muestra tu docente en clase.'),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onEscanear,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Escanear código QR'),
        ),
      ],
    );
  }
}
