import 'package:flutter/material.dart';

import '../../../domain/entities/curso.dart';
import '../../../domain/repositories/curso_repository.dart';
import '../../../domain/usecases/asistencia_usecases.dart';
import '../../../routes/app_routes.dart';
import '../../theme/app_colors.dart';

/// Pestaña de estadísticas del docente: rendimiento de asistencia por materia.
///
/// Todo sale de los contadores que el servidor guarda en grupos/{id}
/// (porcentaje, meta y promedio por clase) y de las sesiones de las
/// últimas 4 semanas (tendencia).
class EstadisticasDocente extends StatelessWidget {
  const EstadisticasDocente({
    super.key,
    required this.cursos,
    required this.obtenerTendenciaSemanal,
  });

  /// Cursos del docente (el mismo stream de la pestaña Inicio).
  final Stream<List<Curso>> cursos;
  final ObtenerTendenciaSemanal obtenerTendenciaSemanal;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Curso>>(
      stream: cursos,
      builder: (context, snapshot) {
        final lista = snapshot.data;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const Text(
              'Rendimiento de Asistencia',
              style: TextStyle(
                color: AppColors.primaryDark,
                fontSize: 26,
                height: 1.3,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.26,
              ),
            ),

            const SizedBox(height: 24),

            // Asistencia por materia
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Asistencia por Materia',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (lista != null && lista.isNotEmpty)
                  Text(
                    '${lista.length} '
                    '${lista.length == 1 ? 'asignatura' : 'asignaturas'}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            if (snapshot.hasError)
              _Mensaje(
                icono: Icons.cloud_off,
                texto: snapshot.error is CursoError
                    ? (snapshot.error as CursoError).mensaje
                    : 'No se pudieron cargar las estadísticas.',
              )
            else if (lista == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (lista.isEmpty)
              const _Mensaje(
                icono: Icons.insights_outlined,
                texto: 'Cuando crees cursos verás aquí su asistencia.',
              )
            else
              for (final curso in lista) ...[
                _TarjetaAsistencia(
                  // La key evita que una tarjeta reutilice la tendencia de otra
                  key: ValueKey(curso.id),
                  curso: curso,
                  obtenerTendenciaSemanal: obtenerTendenciaSemanal,
                ),
                const SizedBox(height: 16),
              ],
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------
// Nivel de la asistencia frente a la meta
// ---------------------------------------------------------------------

enum _Nivel {
  sinDatos(
    'Sin clases aún',
    AppColors.surfaceHigh,
    AppColors.textSecondary,
    AppColors.outlineVariant,
  ),
  optimo(
    'Óptimo',
    AppColors.primaryFixed,
    AppColors.primaryDark,
    AppColors.primary,
  ),
  bueno(
    'Bueno',
    AppColors.attendancePresent,
    AppColors.primary,
    AppColors.primary,
  ),
  regular(
    'Regular',
    AppColors.tertiaryFixed,
    AppColors.onTertiaryContainer,
    AppColors.tertiary,
  );

  const _Nivel(this.etiqueta, this.fondo, this.texto, this.color);

  final String etiqueta;
  final Color fondo; // fondo de la etiqueta
  final Color texto; // texto de la etiqueta
  final Color color; // banda lateral, barra y tendencia

  /// Óptimo: 5 puntos o más sobre la meta. Bueno: en la meta o por encima.
  /// Regular: por debajo de la meta.
  static _Nivel de(Curso curso) {
    if (curso.sesionesCerradas == 0 || curso.totalRegistros == 0) {
      return sinDatos;
    }
    final diferencia = curso.diferenciaMeta;
    if (diferencia >= 0.05) return optimo;
    if (diferencia >= 0) return bueno;
    return regular;
  }
}

String _porcentaje(double valor) => '${(valor * 100).toStringAsFixed(1)}%';

// ---------------------------------------------------------------------
// Tarjeta de una materia
// ---------------------------------------------------------------------

class _TarjetaAsistencia extends StatefulWidget {
  const _TarjetaAsistencia({
    super.key,
    required this.curso,
    required this.obtenerTendenciaSemanal,
  });

  final Curso curso;
  final ObtenerTendenciaSemanal obtenerTendenciaSemanal;

  @override
  State<_TarjetaAsistencia> createState() => _TarjetaAsistenciaState();
}

class _TarjetaAsistenciaState extends State<_TarjetaAsistencia> {
  // Se crea una sola vez para no repetir la consulta en cada build
  late final Stream<List<double?>> _tendencia = widget.obtenerTendenciaSemanal(
    widget.curso.id ?? '',
  );

  @override
  Widget build(BuildContext context) {
    final curso = widget.curso;
    final nivel = _Nivel.de(curso);
    final hayDatos = nivel != _Nivel.sinDatos;
    final diferencia = curso.diferenciaMeta;

    return Container(
      clipBehavior: Clip.antiAlias,
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
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 6, color: nivel.color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Grupo, alumnos y etiqueta
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'GRUPO ${curso.numeroGrupo} • '
                            '${curso.totalEstudiantes} Alumnos',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _Etiqueta(
                          nivel: nivel,
                          texto: hayDatos
                              ? '${_porcentaje(curso.porcentajeAsistencia)} '
                                    '${nivel.etiqueta}'
                              : nivel.etiqueta,
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

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

                    const SizedBox(height: 12),

                    // Barra de asistencia
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: hayDatos ? curso.porcentajeAsistencia : 0,
                        minHeight: 8,
                        color: nivel.color,
                        backgroundColor: AppColors.surfaceContainer,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Meta y diferencia
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Meta semestral: '
                            '${(curso.metaAsistencia * 100).round()}%',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (hayDatos)
                          Text(
                            diferencia >= 0
                                ? '+${_porcentaje(diferencia)} sobre el umbral'
                                : '-${_porcentaje(-diferencia)} bajo meta',
                            style: TextStyle(
                              color: diferencia >= 0
                                  ? AppColors.textSecondary
                                  : AppColors.attendanceWarningText,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Promedio por clase y tendencia
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(child: _Promedios(curso: curso)),
                          const SizedBox(width: 8),
                          StreamBuilder<List<double?>>(
                            stream: _tendencia,
                            builder: (context, snapshot) => _Tendencia(
                              valores: snapshot.data ?? const [],
                              color: nivel == _Nivel.sinDatos
                                  ? AppColors.primary
                                  : nivel.color,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Ver detalle (Material transparente para que se vea
                    // el efecto al tocar sobre el fondo blanco)
                    Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: curso.id == null
                            ? null
                            : () => Navigator.pushNamed(
                                context,
                                AppRoutes.detalleCurso,
                                arguments: curso.id,
                              ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Icon(
                                Icons.list_alt,
                                size: 18,
                                color: AppColors.primaryDark,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Ver detalle de grupo y alumnos',
                                  style: TextStyle(
                                    color: AppColors.primaryDark,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward,
                                size: 18,
                                color: AppColors.primaryDark,
                              ),
                            ],
                          ),
                        ),
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

/// Píldora con el porcentaje y el nivel (ej. "● 92.5% Óptimo").
class _Etiqueta extends StatelessWidget {
  const _Etiqueta({required this.nivel, required this.texto});

  final _Nivel nivel;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: nivel.fondo,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: nivel.texto,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            texto,
            style: TextStyle(
              color: nivel.texto,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// "PROMEDIO POR CLASE" con asistencias, faltas y justificadas.
class _Promedios extends StatelessWidget {
  const _Promedios({required this.curso});

  final Curso curso;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PROMEDIO POR CLASE',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 10,
          runSpacing: 4,
          children: [
            _Dato(
              color: AppColors.primary,
              texto: '${curso.promedioPresentes.round()} Asist.',
              destacado: true,
            ),
            _Dato(
              color: AppColors.secondary,
              texto: '${curso.promedioAusentes.round()} Faltas',
            ),
            _Dato(
              color: AppColors.tertiary,
              texto: '${curso.promedioJustificadas.round()} Just.',
            ),
          ],
        ),
      ],
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({
    required this.color,
    required this.texto,
    this.destacado = false,
  });

  final Color color;
  final String texto;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          texto,
          style: TextStyle(
            color: destacado ? AppColors.textPrimary : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: destacado ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Mini barras de las últimas semanas; la más reciente va más oscura.
/// Una semana sin clases se ve como una barra gris baja.
class _Tendencia extends StatelessWidget {
  const _Tendencia({required this.valores, required this.color});

  final List<double?> valores;
  final Color color;

  static const _alturaMax = 22.0;
  static const _alturaMin = 4.0;

  @override
  Widget build(BuildContext context) {
    final semanas = valores.isEmpty ? 4 : valores.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$semanas sem.',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: _alturaMax,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < semanas; i++) ...[
                if (i > 0) const SizedBox(width: 3),
                _barra(
                  i < valores.length ? valores[i] : null,
                  // De más clara (antigua) a más oscura (actual)
                  0.4 + 0.6 * (i + 1) / semanas,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _barra(double? valor, double opacidad) {
    final altura = valor == null
        ? _alturaMin
        : _alturaMin + (_alturaMax - _alturaMin) * valor.clamp(0.0, 1.0);
    return Container(
      width: 6,
      height: altura,
      decoration: BoxDecoration(
        color: valor == null
            ? AppColors.surfaceHigh
            : color.withValues(alpha: opacidad),
        borderRadius: BorderRadius.circular(2),
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
