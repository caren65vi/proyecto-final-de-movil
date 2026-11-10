import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/entities/curso.dart';
import '../../../domain/entities/usuario.dart';
import '../../../routes/app_routes.dart';
import '../../theme/app_colors.dart';

// Tono del diseño que no está en AppColors
const Color _onPrimaryFixedVariant = Color(0xFF155041);

/// Pestaña de perfil del docente: identidad, contacto y cierre de sesión.
class PerfilDocente extends StatelessWidget {
  const PerfilDocente({
    super.key,
    required this.usuario,
    required this.cursos,
    required this.onCerrarSesion,
    required this.onVerCursos,
  });

  final Usuario usuario;

  /// Cursos del docente (el mismo stream de la pestaña Inicio).
  final Stream<List<Curso>> cursos;
  final VoidCallback onCerrarSesion;

  /// Al tocar "Cursos Activos": lleva a la lista de cursos (pestaña Inicio).
  final VoidCallback onVerCursos;

  // Iniciales del nombre para el avatar (ej. "Carlos Mendoza" → "CM")
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
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Correo copiado')));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // Identidad del docente
        Center(
          child: Stack(
            children: [
              Container(
                width: 96,
                height: 96,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: Text(
                    _iniciales,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryDark,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'Prof. ${usuario.nombre}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 8),

        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryFixed,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryDark,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Docente',
                  style: TextStyle(
                    color: _onPrimaryFixedVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Métricas del periodo
        const _TituloSeccion('Métricas del Periodo'),
        const SizedBox(height: 8),
        StreamBuilder<List<Curso>>(
          stream: cursos,
          builder: (context, snapshot) =>
              _Metricas(cursos: snapshot.data, onVerCursos: onVerCursos),
        ),

        const SizedBox(height: 24),

        // Gestión académica
        const _TituloSeccion('Gestión Académica'),
        const SizedBox(height: 8),
        Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.apartment_outlined,
                size: 20,
                color: AppColors.primaryDark,
              ),
            ),
            title: const Text(
              'Facultades / Carreras',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: const Text(
              'Crea las facultades para tus cursos',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right, color: AppColors.outline),
            onTap: () => Navigator.pushNamed(
              context,
              AppRoutes.facultades,
              arguments: usuario,
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Ubicación y despacho
        const _TituloSeccion('Ubicación y Despacho'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
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
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.alternate_email,
                  size: 20,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(width: 12),
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
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Copiar correo',
                onPressed: () => _copiarCorreo(context),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceLow,
                  foregroundColor: AppColors.primaryDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.content_copy, size: 18),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Cierre de sesión
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.surfaceContainer,
              foregroundColor: AppColors.attendanceWarningText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
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

/// Cursos activos y estudiantes matriculados, calculados con los cursos reales.
class _Metricas extends StatelessWidget {
  const _Metricas({required this.cursos, required this.onVerCursos});

  /// null mientras carga.
  final List<Curso>? cursos;
  final VoidCallback onVerCursos;

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);

    // Activo = todavía no termina (los que empiezan después también cuentan)
    final activos = (cursos ?? const <Curso>[])
        .where((c) => !c.fechaFin.isBefore(inicioHoy))
        .toList();

    // Primera palabra de cada materia (ej. "Cálculo, Estructuras, Métodos")
    final nombres = {
      for (final c in activos)
        if (c.nombreMateria.trim().isNotEmpty)
          c.nombreMateria.trim().split(RegExp(r'\s+')).first,
    }.join(', ');

    final matriculados = activos.fold<int>(
      0,
      (total, c) => total + c.totalEstudiantes,
    );

    // Periodo de los cursos activos (ej. "2026-2"); si hay varios, se omite
    final periodos = {for (final c in activos) c.periodoId};
    final detalleEstudiantes = periodos.length == 1
        ? 'Matriculados ${periodos.first}'
        : 'Matriculados';

    final cargando = cursos == null;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _TarjetaMetrica(
              icono: Icons.auto_stories_outlined,
              fondoIcono: AppColors.surfaceContainer,
              valor: cargando ? '–' : '${activos.length}',
              titulo: 'Cursos Activos',
              detalle: cargando
                  ? 'Cargando…'
                  : (nombres.isEmpty ? 'Sin cursos activos' : nombres),
              onTap: onVerCursos,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _TarjetaMetrica(
              icono: Icons.groups,
              fondoIcono: AppColors.primaryFixed,
              valor: cargando ? '–' : '$matriculados',
              titulo: 'Estudiantes',
              detalle: cargando ? 'Cargando…' : detalleEstudiantes,
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaMetrica extends StatelessWidget {
  const _TarjetaMetrica({
    required this.icono,
    required this.fondoIcono,
    required this.valor,
    required this.titulo,
    required this.detalle,
    this.onTap,
  });

  final IconData icono;
  final Color fondoIcono;
  final String valor;
  final String titulo;
  final String detalle;

  /// Si no es null, la tarjeta se puede tocar y muestra una flecha.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _contenido(),
          ),
        ),
      ),
    );
  }

  Widget _contenido() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: fondoIcono,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icono, size: 20, color: AppColors.primaryDark),
            ),
            const Spacer(),
            if (onTap != null)
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.outline,
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          valor,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 26,
            height: 1.1,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          titulo,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          detalle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
      ],
    );
  }
}

class _TituloSeccion extends StatelessWidget {
  final String texto;

  const _TituloSeccion(this.texto);

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
