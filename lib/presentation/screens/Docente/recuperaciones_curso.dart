import 'package:flutter/material.dart';

import '../../../domain/entities/curso.dart';
import '../../../domain/entities/recuperacion.dart';
import '../../../domain/repositories/curso_repository.dart';
import '../../../domain/usecases/curso_usecases.dart';
import '../../theme/app_colors.dart';
import '../../widgets/mensaje_error.dart';

const _diasLargos = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];
const _meses = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

// "Sábado 22 de noviembre"
String _fechaLarga(DateTime d) =>
    '${_diasLargos[d.weekday - 1]} ${d.day} de ${_meses[d.month - 1]}';

// "07:00" → "07:00 AM"
String _hora12(String hora) {
  final partes = hora.split(':');
  final h = int.parse(partes[0]);
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '${h12.toString().padLeft(2, '0')}:${partes[1]} '
      '${h < 12 ? 'AM' : 'PM'}';
}

String _texto(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Sección "Clases de Recuperación" del detalle del curso: lista las
/// programadas, permite iniciar la asistencia solo en su fecha y hora,
/// programar una nueva o eliminarla.
class SeccionRecuperaciones extends StatelessWidget {
  const SeccionRecuperaciones({
    super.key,
    required this.curso,
    required this.recuperaciones,
    required this.programar,
    required this.eliminar,
    required this.onIniciar,
  });

  final Curso curso;
  final Stream<List<Recuperacion>> recuperaciones;
  final ProgramarRecuperacion programar;
  final EliminarRecuperacion eliminar;
  final VoidCallback onIniciar;

  Future<void> _nueva(BuildContext context) async {
    final creada = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoRecuperacion(curso: curso, programar: programar),
    );
    if (creada == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clase de recuperación programada')),
      );
    }
  }

  Future<void> _eliminar(BuildContext context, Recuperacion r) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar recuperación'),
        content: Text(
          '¿Eliminar la clase del ${_fechaLarga(r.fecha).toLowerCase()} '
          'de ${_hora12(r.inicio)} a ${_hora12(r.fin)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !context.mounted) return;
    try {
      await eliminar(curso.id!, r.id!);
    } on CursoError catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Recuperacion>>(
      stream: recuperaciones,
      builder: (context, snapshot) {
        // Solo las que todavía no terminan
        final proximas = (snapshot.data ?? const <Recuperacion>[])
            .where((r) => !r.yaPaso())
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.event_repeat,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Clases de Recuperación',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _nueva(context),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryDark,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Programar'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (snapshot.hasError)
              const Text(
                'No se pudieron cargar las recuperaciones',
                style: TextStyle(color: AppColors.error, fontSize: 12),
              )
            else if (proximas.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No hay clases de recuperación programadas. '
                  'Úsalas para dictar una clase fuera del horario normal.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              )
            else
              for (final r in proximas) ...[
                _TarjetaRecuperacion(
                  recuperacion: r,
                  aula: curso.aula,
                  onIniciar: onIniciar,
                  onEliminar: () => _eliminar(context, r),
                ),
                const SizedBox(height: 12),
              ],
          ],
        );
      },
    );
  }
}

class _TarjetaRecuperacion extends StatelessWidget {
  const _TarjetaRecuperacion({
    required this.recuperacion,
    required this.aula,
    required this.onIniciar,
    required this.onEliminar,
  });

  final Recuperacion recuperacion;
  final String aula;
  final VoidCallback onIniciar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    final r = recuperacion;
    final disponible = r.disponible();
    final detalle = [
      '${_hora12(r.inicio)} – ${_hora12(r.fin)}',
      if (aula.trim().isNotEmpty) aula.trim(),
    ].join(' • ');

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
            Container(width: 6, color: AppColors.tertiary),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _fechaLarga(r.fecha),
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                detalle,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              if (r.motivo.isNotEmpty)
                                Text(
                                  r.motivo,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Eliminar',
                          onPressed: onEliminar,
                          color: AppColors.attendanceWarningText,
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: SizedBox(
                        height: 44,
                        child: FilledButton.icon(
                          onPressed: disponible ? onIniciar : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryDark,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: Icon(
                            disponible
                                ? Icons.play_arrow_rounded
                                : Icons.lock_clock,
                            size: 20,
                          ),
                          label: const Text('Iniciar clase'),
                        ),
                      ),
                    ),
                    if (!disponible) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Se habilita ${Curso.minutosAntes} min antes de las '
                        '${_hora12(r.inicio)} de ese día',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
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

/// Formulario para programar una clase de recuperación.
class _DialogoRecuperacion extends StatefulWidget {
  const _DialogoRecuperacion({required this.curso, required this.programar});

  final Curso curso;
  final ProgramarRecuperacion programar;

  @override
  State<_DialogoRecuperacion> createState() => _DialogoRecuperacionState();
}

class _DialogoRecuperacionState extends State<_DialogoRecuperacion> {
  DateTime? _fecha;
  TimeOfDay? _desde;
  TimeOfDay? _hasta;
  final _motivo = TextEditingController();
  bool _guardando = false;
  String? _error;

  // Tras el primer intento, los campos vacíos se marcan en rojo
  bool _intento = false;

  String? get _errorFecha =>
      _intento && _fecha == null ? 'Elige la fecha' : null;

  String? get _errorHoras {
    if (!_intento) return null;
    if (_desde == null || _hasta == null) {
      return 'Elige la hora de inicio y fin';
    }
    final inicio = _desde!.hour * 60 + _desde!.minute;
    final fin = _hasta!.hour * 60 + _hasta!.minute;
    if (fin <= inicio) return 'La hora de fin debe ser posterior al inicio';
    return null;
  }

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final primero = DateTime(hoy.year, hoy.month, hoy.day);
    final inicioCurso = widget.curso.fechaInicio;
    final desde = inicioCurso.isAfter(primero) ? inicioCurso : primero;
    final hasta = widget.curso.fechaFin;
    if (hasta.isBefore(desde)) {
      setState(() => _error = 'El período del curso ya terminó');
      return;
    }
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha ?? desde,
      firstDate: desde,
      lastDate: hasta,
    );
    if (elegida != null) {
      setState(() {
        _fecha = elegida;
        _error = null;
      });
    }
  }

  Future<void> _elegirHora({required bool esDesde}) async {
    final elegida = await showTimePicker(
      context: context,
      initialTime:
          (esDesde ? _desde : _hasta) ??
          TimeOfDay(hour: esDesde ? 8 : 10, minute: 0),
    );
    if (elegida == null) return;
    setState(() {
      esDesde ? _desde = elegida : _hasta = elegida;
      _error = null;
    });
  }

  Future<void> _guardar() async {
    setState(() {
      _intento = true;
      _error = null;
    });
    // Fecha u horas faltantes: se marcan en rojo bajo cada campo
    if (_errorFecha != null || _errorHoras != null) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.programar(
        widget.curso,
        Recuperacion(
          fecha: _fecha!,
          inicio: _texto(_desde!),
          fin: _texto(_hasta!),
          motivo: _motivo.text,
        ),
        widget.curso.docenteUid,
      );
      if (mounted) Navigator.pop(context, true);
    } on CursoError catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo programar. Intenta de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Widget _campo({
    required IconData icono,
    required String texto,
    required VoidCallback onTap,
    bool conError = false,
  }) {
    return InkWell(
      onTap: _guardando ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: conError ? AppColors.error : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(icono, size: 18, color: AppColors.primaryDark),
            const SizedBox(width: 8),
            Expanded(child: Text(texto)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Programar recuperación'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _campo(
              icono: Icons.event,
              texto: _fecha == null ? 'Elegir fecha' : _fechaLarga(_fecha!),
              onTap: _elegirFecha,
              conError: _errorFecha != null,
            ),
            if (_errorFecha != null) ErrorDeCampo(texto: _errorFecha!),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _campo(
                    icono: Icons.schedule,
                    texto: _desde == null ? 'Desde' : _hora12(_texto(_desde!)),
                    onTap: () => _elegirHora(esDesde: true),
                    conError: _errorHoras != null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _campo(
                    icono: Icons.schedule,
                    texto: _hasta == null ? 'Hasta' : _hora12(_texto(_hasta!)),
                    onTap: () => _elegirHora(esDesde: false),
                    conError: _errorHoras != null,
                  ),
                ),
              ],
            ),
            if (_errorHoras != null) ErrorDeCampo(texto: _errorHoras!),
            const SizedBox(height: 8),
            TextField(
              controller: _motivo,
              enabled: !_guardando,
              maxLength: ProgramarRecuperacion.largoMaximoMotivo,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Motivo (opcional). Ej. Festivo del lunes',
              ),
            ),
            // Error de Firestore (ej. choca con una clase normal)
            if (_error != null) ...[
              const SizedBox(height: 4),
              MensajeError(texto: _error!),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: _guardando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Programar'),
        ),
      ],
    );
  }
}
