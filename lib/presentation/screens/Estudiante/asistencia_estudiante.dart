import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/entities/materia_estudiante.dart';
import '../../theme/app_colors.dart';

/// Pestaña de asistencia del estudiante: progreso de asistencia por materia,
/// cuánto margen de faltas le queda y si está en riesgo.
///
/// Recibe las materias ya cargadas por HomeEstudiante (no abre otra consulta).
class AsistenciaEstudiante extends StatelessWidget {
  const AsistenciaEstudiante({
    super.key,
    required this.materias,
    required this.cargando,
    this.error,
  });

  final List<MateriaEstudiante> materias;
  final bool cargando;
  final String? error;

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      // Espacio abajo para que el botón "Escanear" no tape la última tarjeta
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        if (error != null)
          _Mensaje(icono: Icons.cloud_off, texto: error!)
        else if (materias.isEmpty)
          const _Mensaje(
            icono: Icons.fact_check_outlined,
            texto: 'Todavía no estás inscrito en ninguna materia.',
          )
        else
          for (final materia in materias) ...[
            _TarjetaAsistencia(materia: materia),
            const SizedBox(height: 16),
          ],
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Cálculos de una materia
// ---------------------------------------------------------------------

/// Horas de una materia. Solo cuentan las horas asistidas: la falta
/// justificada no suma asistencia (se muestra aparte).
class _Resumen {
  _Resumen(MateriaEstudiante materia)
    : totales = materia.curso.horasTotales.toDouble(),
      meta = materia.curso.metaAsistencia,
      asistidas = materia.inscripcion.horasAsistidas,
      faltas = materia.inscripcion.horasFalta,
      justificadas = materia.inscripcion.horasJustificadas;

  final double totales; // horas del semestre
  final double meta; // 0.8 = 80 %
  final double asistidas;
  final double faltas;
  final double justificadas;

  double get dictadas => asistidas + faltas + justificadas;
  double get inasistencias => faltas + justificadas;
  double get porcentaje => dictadas == 0 ? 1 : asistidas / dictadas;

  /// Horas que se pueden perder en todo el semestre sin bajar de la meta.
  double get maxFaltas => totales * (1 - meta);

  /// Lo que queda de ese margen (negativo = ya se pasó).
  double get margen => maxFaltas - inasistencias;

  /// Horas seguidas que debe asistir para volver a la meta.
  double get horasParaMeta {
    if (meta >= 1) return 0;
    return math.max(0, (meta * dictadas - asistidas) / (1 - meta));
  }

  /// Parte del margen de faltas por debajo de la cual se pasa a "Normal"
  /// (0.25 = le queda una cuarta parte o menos).
  static const margenNormal = 0.25;

  _Estado get estado {
    if (dictadas == 0) return _Estado.sinClases;
    if (margen < 0) return _Estado.reprobando;
    if (porcentaje < meta) return _Estado.enRiesgo;
    if (inasistencias == 0) return _Estado.excelente;
    if (margen <= maxFaltas * margenNormal) return _Estado.normal;
    return _Estado.alDia;
  }
}

enum _Estado {
  excelente(
    'Excelente',
    Icons.stars,
    AppColors.primaryDark,
    AppColors.primaryDark,
    Colors.white,
    AppColors.surfaceLow,
  ),
  alDia(
    'Al día',
    Icons.check_circle,
    AppColors.primary,
    AppColors.attendancePresent,
    AppColors.primary,
    AppColors.surfaceLow,
  ),
  normal(
    'Normal',
    Icons.done,
    AppColors.onPrimaryContainer,
    AppColors.tertiaryFixed,
    AppColors.onTertiaryContainer,
    AppColors.surfaceLow,
  ),
  enRiesgo(
    'En riesgo',
    Icons.warning_rounded,
    AppColors.secondary,
    AppColors.secondaryFixed,
    AppColors.attendanceWarningText,
    AppColors.attendanceWarning,
  ),
  reprobando(
    'Reprobando',
    Icons.cancel,
    AppColors.error,
    AppColors.errorContainer,
    AppColors.error,
    AppColors.attendanceWarning,
  ),
  sinClases(
    'Sin clases',
    Icons.schedule,
    AppColors.outlineVariant,
    AppColors.surfaceHigh,
    AppColors.textSecondary,
    AppColors.surfaceLow,
  );

  const _Estado(
    this.etiqueta,
    this.icono,
    this.color,
    this.fondoEtiqueta,
    this.textoEtiqueta,
    this.fondoCaja,
  );

  final String etiqueta;
  final IconData icono;
  final Color color; // banda lateral y barra
  final Color fondoEtiqueta;
  final Color textoEtiqueta;
  final Color fondoCaja; // fondo de las tres cifras

  bool get alerta => this == enRiesgo || this == reprobando;
}

// "64" o "12.8"
String _horas(double valor) => valor == valor.roundToDouble()
    ? valor.toStringAsFixed(0)
    : valor.toStringAsFixed(1);

String _pct(double valor) => '${(valor * 100).round()}%';

// ---------------------------------------------------------------------
// Tarjeta de una materia
// ---------------------------------------------------------------------

class _TarjetaAsistencia extends StatelessWidget {
  const _TarjetaAsistencia({required this.materia});

  final MateriaEstudiante materia;

  @override
  Widget build(BuildContext context) {
    final curso = materia.curso;
    final r = _Resumen(materia);
    final estado = r.estado;
    final meta = _pct(r.meta);

    // Textos que cambian según el estado
    final subtitulo = switch (estado) {
      _Estado.excelente => 'Asistencia perfecta',
      _Estado.alDia => 'Meta $meta superada',
      _Estado.normal => 'Margen: ${_horas(r.margen)}h libres',
      _Estado.enRiesgo => 'Requiere +${_horas(r.horasParaMeta)}h asistidas',
      _Estado.reprobando => '> ${_pct(1 - r.meta)} inasistencia',
      _Estado.sinClases => 'Meta semestral: $meta',
    };
    final detalleAsistidas = switch (estado) {
      _Estado.enRiesgo ||
      _Estado.reprobando => 'Faltas: ${_horas(r.inasistencias)}h',
      _Estado.normal => '${_horas(r.inasistencias)}h ausencias',
      _Estado.excelente => 'Completas',
      _ => 'Cumplidas',
    };
    final tercera = switch (estado) {
      _Estado.excelente => (
        titulo: 'Faltas',
        valor: '${_horas(r.inasistencias)} hrs',
        detalle: 'Impecable',
      ),
      _Estado.alDia => (
        titulo: 'Margen seguro',
        valor: '${_horas(r.margen)} hrs',
        detalle: 'Restantes',
      ),
      _Estado.normal => (
        titulo: 'Margen',
        valor: '${_horas(r.margen)} hrs',
        detalle: 'Permitidas',
      ),
      _Estado.enRiesgo => (
        titulo: 'Máx. faltas',
        valor: '${_horas(r.maxFaltas)} hrs',
        detalle: 'Quedan ${_horas(r.margen)}h',
      ),
      _Estado.reprobando => (
        titulo: 'Límite permitido',
        valor: '${_horas(r.maxFaltas)} hrs',
        detalle: 'Excedido',
      ),
      _Estado.sinClases => (
        titulo: 'Máx. faltas',
        valor: '${_horas(r.maxFaltas)} hrs',
        detalle: 'Permitidas',
      ),
    };
    final pie = switch (estado) {
      _Estado.excelente => '${_pct(r.porcentaje)} de asistencia',
      _Estado.alDia => 'Sin riesgo de pérdida',
      _Estado.normal => 'Aprobando',
      _Estado.enRiesgo => 'Límite crítico',
      _Estado.reprobando => 'Sin margen',
      _Estado.sinClases => 'Aún no hay clases dictadas',
    };

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceHigh),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 6, color: estado.color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Grupo y etiqueta de estado
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'GRUPO ${curso.numeroGrupo}',
                              style: TextStyle(
                                color: estado.alerta
                                    ? estado.textoEtiqueta
                                    : AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _Etiqueta(
                              estado: estado,
                              texto: estado == _Estado.sinClases
                                  ? estado.etiqueta
                                  : '${estado.etiqueta} • ${_pct(r.porcentaje)}',
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitulo,
                              style: TextStyle(
                                color: estado.alerta
                                    ? estado.textoEtiqueta
                                    : AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    Text(
                      curso.nombreMateria,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (curso.docenteNombre.isNotEmpty)
                      Text(
                        'Prof. ${curso.docenteNombre}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),

                    const SizedBox(height: 14),

                    // Progreso de asistencia
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Progreso de asistencia',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          r.dictadas == 0
                              ? '0 hrs dictadas'
                              : '${_horas(r.asistidas)} de '
                                    '${_horas(r.dictadas)} hrs '
                                    '(${_pct(r.porcentaje)})',
                          style: TextStyle(
                            color: estado.alerta
                                ? estado.textoEtiqueta
                                : AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _BarraConMeta(
                      valor: r.dictadas == 0 ? 0 : r.porcentaje,
                      meta: r.meta,
                      color: estado.color,
                    ),

                    const SizedBox(height: 12),

                    // Tres cifras
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: estado.fondoCaja,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          _Cifra(
                            titulo: 'Horas totales',
                            valor: '${_horas(r.totales)} hrs',
                            detalle: 'Semestre',
                          ),
                          _Cifra(
                            titulo: 'Asistidas',
                            valor: '${_horas(r.asistidas)} hrs',
                            detalle: detalleAsistidas,
                            alerta: estado.alerta,
                          ),
                          _Cifra(
                            titulo: tercera.titulo,
                            valor: tercera.valor,
                            detalle: tercera.detalle,
                            alerta: estado.alerta,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      pie,
                      style: TextStyle(
                        color: estado.alerta
                            ? estado.textoEtiqueta
                            : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Píldora con ícono, estado y porcentaje (ej. "✓ Al día • 92%").
class _Etiqueta extends StatelessWidget {
  const _Etiqueta({required this.estado, required this.texto});

  final _Estado estado;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: estado.fondoEtiqueta,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(estado.icono, size: 13, color: estado.textoEtiqueta),
          const SizedBox(width: 4),
          Text(
            texto,
            style: TextStyle(
              color: estado.textoEtiqueta,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra de progreso con una marca vertical en la meta y su porcentaje debajo.
class _BarraConMeta extends StatelessWidget {
  const _BarraConMeta({
    required this.valor,
    required this.meta,
    required this.color,
  });

  final double valor;
  final double meta;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth;
        final x = ancho * meta.clamp(0.0, 1.0);
        return SizedBox(
          height: 26,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: valor.clamp(0.0, 1.0),
                    minHeight: 8,
                    color: color,
                    backgroundColor: AppColors.surfaceContainer,
                  ),
                ),
              ),
              // Marca de la meta
              Positioned(
                left: x - 1,
                top: -2,
                child: Container(
                  width: 2,
                  height: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              Positioned(
                // Centrado bajo la marca sin salirse del borde
                left: (x - 14).clamp(0.0, math.max(0.0, ancho - 28)),
                top: 12,
                child: SizedBox(
                  width: 28,
                  child: Text(
                    _pct(meta),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Una de las tres cifras: título, valor y detalle.
class _Cifra extends StatelessWidget {
  const _Cifra({
    required this.titulo,
    required this.valor,
    required this.detalle,
    this.alerta = false,
  });

  final String titulo;
  final String valor;
  final String detalle;
  final bool alerta;

  @override
  Widget build(BuildContext context) {
    final colorAlerta = alerta
        ? AppColors.attendanceWarningText
        : AppColors.textPrimary;
    return Expanded(
      child: Column(
        children: [
          Text(
            titulo,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            valor,
            style: TextStyle(
              color: colorAlerta,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            detalle,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: alerta
                  ? AppColors.attendanceWarningText
                  : AppColors.onPrimaryContainer,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Aviso centrado para la lista vacía o con error.
class _Mensaje extends StatelessWidget {
  const _Mensaje({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icono, size: 32, color: AppColors.outline),
          const SizedBox(height: 8),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
