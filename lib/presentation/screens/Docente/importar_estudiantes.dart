import 'package:flutter/material.dart';

import '../../../domain/entities/resultado_importacion.dart';
import '../../../domain/repositories/curso_repository.dart';
import '../../../domain/usecases/curso_usecases.dart';
import '../../theme/app_colors.dart';

/// Importa la lista de estudiantes en tres pasos:
/// 1. Muestra cómo debe ser el archivo (columnas y un ejemplo).
/// 2. Abre el selector de archivos y lo lee.
/// 3. Muestra cuántos estudiantes se cargaron, o el error.
///
/// Devuelve el resultado, o null si el docente cancela o el archivo falla.
/// [cuandoSeGuardan] explica cuándo quedan inscritos (ej. al guardar el curso).
Future<ResultadoImportacion?> importarEstudiantesConFormato(
  BuildContext context, {
  required ImportarEstudiantes importar,
  required String cuandoSeGuardan,
}) async {
  final continuar = await showDialog<bool>(
    context: context,
    builder: (_) => const _DialogoFormato(),
  );
  if (continuar != true || !context.mounted) return null;

  try {
    final resultado = await importar();
    if (resultado == null || !context.mounted) return null; // canceló
    await showDialog<void>(
      context: context,
      builder: (_) => _DialogoResultado(
        resultado: resultado,
        cuandoSeGuardan: cuandoSeGuardan,
      ),
    );
    return resultado;
  } on CursoError catch (e) {
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (_) => _DialogoError(mensaje: e.mensaje),
      );
    }
    return null;
  } catch (_) {
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (_) => const _DialogoError(
          mensaje: 'No se pudo abrir el archivo. Intenta de nuevo.',
        ),
      );
    }
    return null;
  }
}

// ---------------------------------------------------------------------
// 1. Formato del archivo
// ---------------------------------------------------------------------

class _DialogoFormato extends StatelessWidget {
  const _DialogoFormato();

  static const _columnas = [
    (titulo: 'PROGRAMA', obligatoria: false, ejemplo: 'INGENIERIA DE SISTEMAS'),
    (titulo: 'CODIGOESTUDIANTE', obligatoria: false, ejemplo: '4245172970'),
    (
      titulo: 'MAIL_INST',
      obligatoria: true,
      ejemplo: 'laur.alvarez@udla.edu.co',
    ),
    (
      titulo: 'NOMBRECOMPLETO',
      obligatoria: true,
      ejemplo: 'Alvarez Rojas Laura Camila',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      title: const Row(
        children: [
          Icon(Icons.table_chart_outlined, color: AppColors.primary),
          SizedBox(width: 8),
          Expanded(child: Text('Formato del archivo')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sube un Excel (.xlsx) o CSV. La primera fila son los títulos '
              'y debajo va un estudiante por fila:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),

            // Columnas con su ejemplo
            for (final c in _columnas)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: c.obligatoria
                      ? AppColors.attendancePresent
                      : AppColors.surfaceLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.titulo,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        Text(
                          c.obligatoria ? 'Obligatoria' : 'Opcional',
                          style: TextStyle(
                            color: c.obligatoria
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ej. ${c.ejemplo}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),
            const Text(
              '• El orden de las columnas no importa.\n'
              '• También se aceptan los títulos "correo", "nombre" y "codigo".\n'
              '• Los correos repetidos o mal escritos se omiten y te '
              'diremos en qué fila están.\n'
              '• Se lee solo la primera hoja del Excel.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          icon: const Icon(Icons.upload_file, size: 18),
          label: const Text('Elegir archivo'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// 2. Cargado
// ---------------------------------------------------------------------

class _DialogoResultado extends StatelessWidget {
  const _DialogoResultado({
    required this.resultado,
    required this.cuandoSeGuardan,
  });

  final ResultadoImportacion resultado;
  final String cuandoSeGuardan;

  // Se muestran pocas filas omitidas para que la ventana no sea enorme
  static const _maximoOmitidas = 8;

  @override
  Widget build(BuildContext context) {
    final total = resultado.estudiantes.length;
    final omitidas = resultado.omitidas;
    return AlertDialog(
      icon: const Icon(Icons.check_circle, color: AppColors.primary, size: 40),
      title: Text(
        '$total ${total == 1 ? 'estudiante cargado' : 'estudiantes cargados'}',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Del archivo "${resultado.nombreArchivo}". $cuandoSeGuardan',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            if (omitidas.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.tertiaryFixed,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${omitidas.length} '
                      '${omitidas.length == 1 ? 'fila omitida' : 'filas omitidas'}:',
                      style: const TextStyle(
                        color: AppColors.onTertiaryContainer,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    for (final o in omitidas.take(_maximoOmitidas))
                      Text(
                        '• Fila ${o.fila}: ${o.motivo}',
                        style: const TextStyle(
                          color: AppColors.onTertiaryContainer,
                          fontSize: 12,
                        ),
                      ),
                    if (omitidas.length > _maximoOmitidas)
                      Text(
                        '… y ${omitidas.length - _maximoOmitidas} más',
                        style: const TextStyle(
                          color: AppColors.onTertiaryContainer,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: const Text('Entendido'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// 3. Error
// ---------------------------------------------------------------------

class _DialogoError extends StatelessWidget {
  const _DialogoError({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.error_outline, color: AppColors.error, size: 40),
      title: const Text('No se pudo cargar el archivo'),
      content: SingleChildScrollView(
        child: Text(
          '$mensaje\n\n'
          'Revisa que el archivo tenga las columnas MAIL_INST y '
          'NOMBRECOMPLETO en la primera fila e inténtalo de nuevo.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: const Text('Entendido'),
        ),
      ],
    );
  }
}
