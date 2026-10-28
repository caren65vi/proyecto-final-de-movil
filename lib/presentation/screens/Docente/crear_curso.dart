import 'package:flutter/material.dart';

import '../../../domain/entities/bloque_horario.dart';
import '../../../domain/entities/curso.dart';
import '../../../domain/entities/estudiante_inscrito.dart';
import '../../../domain/entities/usuario.dart';
import '../../../domain/repositories/curso_repository.dart';
import '../../../domain/usecases/curso_usecases.dart';
import '../../theme/app_colors.dart';

/// Una sesión semanal del curso: día y rango de horas.
class _Sesion {
  final int dia; // índice en _CrearCursoScreenState._dias
  final TimeOfDay desde;
  final TimeOfDay hasta;

  const _Sesion({required this.dia, required this.desde, required this.hasta});
}

/// Formulario para registrar un curso nuevo y guardarlo en Firestore.
class CrearCursoScreen extends StatefulWidget {
  const CrearCursoScreen({
    super.key,
    required this.usuario,
    required this.cursoRepository,
  });

  // Docente con sesión abierta: queda como dueño del curso
  final Usuario usuario;
  final CursoRepository cursoRepository;

  @override
  State<CrearCursoScreen> createState() => _CrearCursoScreenState();
}

class _CrearCursoScreenState extends State<CrearCursoScreen> {
  static const _facultades = [
    'Facultad de Ingeniería',
    'Ciencias Básicas',
    'Ciencias de la Salud',
    'Arquitectura y Diseño',
  ];
  static const _dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
  static const _diasLargos = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
  ];
  static const _meses = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];

  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _salonController = TextEditingController();

  String? _facultad;
  int? _grupo;
  DateTimeRange? _periodo;

  // Horario
  final List<_Sesion> _sesiones = [];
  bool _editandoSesion = true;
  int _diaNuevaSesion = 0;
  TimeOfDay? _desde;
  TimeOfDay? _hasta;

  // Radio (en metros) dentro del cual se valida la asistencia
  double _radio = 50;

  // Ubicación del curso (se fija con el GPS del docente)
  double? _latitud;
  double? _longitud;
  bool _buscandoUbicacion = false;

  // Lista de estudiantes importada del archivo (opcional)
  List<EstudianteInscrito> _estudiantes = [];
  String? _nombreArchivo;

  bool _guardando = false;

  // Casos de uso, armados con el repositorio que llega de afuera
  late final _crearCurso = CrearCurso(widget.cursoRepository);
  late final _obtenerMiUbicacion = ObtenerMiUbicacion(widget.cursoRepository);
  late final _importarEstudiantes = ImportarEstudiantes(
    widget.cursoRepository,
  );

  @override
  void dispose() {
    _nombreController.dispose();
    _salonController.dispose();
    super.dispose();
  }

  // Ej. "10 Feb 2025"
  String _fecha(DateTime d) => '${d.day} ${_meses[d.month - 1]} ${d.year}';

  // Ej. "07:00 AM"
  String _hora(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final periodo = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '${h.toString().padLeft(2, '0')}:$m $periodo';
  }

  int _minutos(TimeOfDay t) => t.hour * 60 + t.minute;

  // Ej. "07:00" (formato 24 h que se guarda en Firestore)
  String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: AppColors.error),
    );
  }

  Future<void> _elegirPeriodo() async {
    final ahora = DateTime.now();
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(ahora.year - 1),
      lastDate: DateTime(ahora.year + 2),
      initialDateRange: _periodo,
      helpText: 'Rango de fechas',
      saveText: 'Guardar período',
    );
    if (rango != null) setState(() => _periodo = rango);
  }

  Future<void> _elegirHora({required bool esDesde}) async {
    final hora = await showTimePicker(
      context: context,
      initialTime: (esDesde ? _desde : _hasta) ??
          const TimeOfDay(hour: 7, minute: 0),
      helpText: esDesde ? 'Hora de inicio' : 'Hora de fin',
    );
    if (hora == null) return;
    setState(() => esDesde ? _desde = hora : _hasta = hora);
  }

  void _reiniciarSesion() {
    setState(() {
      _diaNuevaSesion = 0;
      _desde = null;
      _hasta = null;
    });
  }

  void _confirmarSesion() {
    if (_desde == null || _hasta == null) {
      _mostrarError('Elige la hora de inicio y de fin.');
      return;
    }
    if (_minutos(_hasta!) <= _minutos(_desde!)) {
      _mostrarError('La hora de fin debe ser posterior a la de inicio.');
      return;
    }
    setState(() {
      _sesiones.add(
        _Sesion(dia: _diaNuevaSesion, desde: _desde!, hasta: _hasta!),
      );
      _editandoSesion = false;
      _desde = null;
      _hasta = null;
    });
  }

  Future<void> _fijarUbicacion() async {
    setState(() => _buscandoUbicacion = true);
    try {
      final ubicacion = await _obtenerMiUbicacion();
      if (!mounted) return;
      setState(() {
        _latitud = ubicacion.latitud;
        _longitud = ubicacion.longitud;
      });
    } on CursoError catch (e) {
      if (mounted) _mostrarError(e.mensaje);
    } finally {
      if (mounted) setState(() => _buscandoUbicacion = false);
    }
  }

  Future<void> _elegirArchivo() async {
    try {
      final resultado = await _importarEstudiantes();
      if (resultado == null || !mounted) return; // canceló
      setState(() {
        _estudiantes = resultado.estudiantes;
        _nombreArchivo = resultado.nombreArchivo;
      });
    } on CursoError catch (e) {
      if (mounted) _mostrarError(e.mensaje);
    }
  }

  Future<void> _guardarCurso() async {
    final formularioValido = _formKey.currentState!.validate();
    if (!formularioValido) return;

    if (_periodo == null) {
      _mostrarError('Define el período del curso.');
      return;
    }
    if (_sesiones.isEmpty) {
      _mostrarError('Agrega al menos un horario de clase.');
      return;
    }
    if (_latitud == null || _longitud == null) {
      _mostrarError('Fija la ubicación del curso.');
      return;
    }

    final curso = Curso(
      nombreMateria: _nombreController.text.trim(),
      facultad: _facultad!,
      numeroGrupo: '$_grupo',
      aula: _salonController.text.trim(),
      docenteUid: widget.usuario.uid,
      docenteNombre: widget.usuario.nombre,
      fechaInicio: _periodo!.start,
      fechaFin: _periodo!.end,
      horario: [
        for (final s in _sesiones)
          BloqueHorario(
            dia: s.dia + 1, // _dias empieza en lunes = 0
            inicio: _hhmm(s.desde),
            fin: _hhmm(s.hasta),
          ),
      ],
      latitud: _latitud!,
      longitud: _longitud!,
      radioMetros: _radio.round(),
    );

    setState(() => _guardando = true);
    try {
      await _crearCurso(curso, _estudiantes);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Curso creado')));
      Navigator.pop(context, true);
    } on CursoError catch (e) {
      if (mounted) _mostrarError(e.mensaje);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: AppColors.primary.withValues(alpha: 0.08),
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/ceiba_logo.png',
                width: 32,
                height: 32,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Registrar Curso',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const Text(
              'Nuevo Curso',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 26,
                height: 1.3,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.26,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetalles(),
            const SizedBox(height: 16),
            _buildDuracion(),
            const SizedBox(height: 16),
            _buildHorario(),
            const SizedBox(height: 16),
            _buildUbicacion(),
            const SizedBox(height: 16),
            _buildEstudiantes(),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: _guardando ? null : _guardarCurso,
                child: _guardando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Crear Curso'),
                          SizedBox(width: 8),
                          Icon(
                            Icons.check_circle_outline,
                            size: 20,
                            color: Color(0xFFFFE088),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(foregroundColor: AppColors.outline),
                child: const Text(
                  'Descartar',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Detalles básicos ----------

  Widget _buildDetalles() {
    return _Tarjeta(
      titulo: 'Detalles Básicos',
      children: [
        TextFormField(
          controller: _nombreController,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(fontSize: 16),
          decoration: _decoracion('Nombre del curso', Icons.menu_book_outlined),
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Escribe el nombre del curso'
              : null,
        ),
        DropdownButtonFormField<String>(
          initialValue: _facultad,
          isExpanded: true,
          icon: const Icon(Icons.expand_more, color: AppColors.outline),
          decoration: _decoracion(
            'Selecciona Facultad / Carrera',
            Icons.apartment_outlined,
          ),
          items: [
            for (final f in _facultades)
              DropdownMenuItem(value: f, child: Text(f)),
          ],
          onChanged: (v) => setState(() => _facultad = v),
          validator: (v) => v == null ? 'Selecciona la facultad' : null,
        ),
        TextFormField(
          controller: _salonController,
          decoration: _decoracion(
            'Salón de clase (Ej. Aula Magna 204, Lab B)',
            Icons.meeting_room_outlined,
          ),
        ),
        DropdownButtonFormField<int>(
          initialValue: _grupo,
          isExpanded: true,
          icon: const Icon(Icons.expand_more, color: AppColors.outline),
          decoration: _decoracion('Selecciona Grupo', Icons.groups_outlined),
          items: [
            for (var g = 1; g <= 10; g++)
              DropdownMenuItem(value: g, child: Text('Grupo $g')),
          ],
          onChanged: (v) => setState(() => _grupo = v),
          validator: (v) => v == null ? 'Selecciona el grupo' : null,
        ),
      ],
    );
  }

  InputDecoration _decoracion(String hint, IconData icono) {
    final borde = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.outline, fontSize: 14),
      prefixIcon: Icon(icono, size: 20, color: AppColors.outline),
      filled: true,
      fillColor: AppColors.surfaceLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: borde,
      enabledBorder: borde,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }

  // ---------- Duración ----------

  Widget _buildDuracion() {
    return _Tarjeta(
      titulo: 'Duración de Clases',
      accion: TextButton.icon(
        onPressed: _elegirPeriodo,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
          visualDensity: VisualDensity.compact,
          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        icon: const Icon(Icons.edit_calendar_outlined, size: 16),
        label: const Text('Editar período'),
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: _CajaValor(
                etiqueta: 'Inicio',
                icono: Icons.event,
                colorIcono: AppColors.primaryDark,
                valor: _periodo == null ? null : _fecha(_periodo!.start),
                onTap: _elegirPeriodo,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _CajaValor(
                etiqueta: 'Fin',
                icono: Icons.event_busy,
                colorIcono: AppColors.attendanceWarningText,
                valor: _periodo == null ? null : _fecha(_periodo!.end),
                onTap: _elegirPeriodo,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------- Horario ----------

  Widget _buildHorario() {
    final n = _sesiones.length;
    return _Tarjeta(
      titulo: 'Horario de Clases',
      accion: n == 0
          ? null
          : _Etiqueta(
              n == 1 ? '1 sesión agregada' : '$n sesiones agregadas',
            ),
      children: [
        for (var i = 0; i < _sesiones.length; i++) _buildSesion(i),
        if (_editandoSesion)
          _buildNuevaSesion()
        else
          OutlinedButton.icon(
            onPressed: () => setState(() => _editandoSesion = true),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryDark,
              side: const BorderSide(color: AppColors.primaryDark),
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Adicionar otro horario'),
          ),
      ],
    );
  }

  Widget _buildSesion(int i) {
    final s = _sesiones[i];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primaryFixed.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.schedule,
              size: 18,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _diasLargos[s.dia],
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${_hora(s.desde)} - ${_hora(s.hasta)}',
                  style: const TextStyle(
                    color: AppColors.outline,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Eliminar horario',
            onPressed: () => setState(() {
              _sesiones.removeAt(i);
              if (_sesiones.isEmpty) _editandoSesion = true;
            }),
            color: AppColors.outline,
            icon: const Icon(Icons.delete_outline, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildNuevaSesion() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Nuevo intervalo',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              GestureDetector(
                onTap: _reiniciarSesion,
                child: const Text(
                  'Reiniciar',
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Día de la sesión
          Row(
            children: [
              for (var i = 0; i < _dias.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: _ChipDia(
                    texto: _dias[i],
                    seleccionado: _diaNuevaSesion == i,
                    onTap: () => setState(() => _diaNuevaSesion = i),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Desde / Hasta
          Row(
            children: [
              Expanded(
                child: _CajaValor(
                  etiqueta: 'Desde',
                  icono: Icons.schedule,
                  colorIcono: AppColors.primaryDark,
                  valor: _desde == null ? null : _hora(_desde!),
                  fondo: AppColors.surface,
                  onTap: () => _elegirHora(esDesde: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CajaValor(
                  etiqueta: 'Hasta',
                  icono: Icons.schedule,
                  colorIcono: AppColors.primaryDark,
                  valor: _hasta == null ? null : _hora(_hasta!),
                  fondo: AppColors.surface,
                  onTap: () => _elegirHora(esDesde: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          FilledButton.icon(
            onPressed: _confirmarSesion,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Confirmar horario'),
          ),
        ],
      ),
    );
  }

  // ---------- Ubicación ----------

  Widget _buildUbicacion() {
    final radioTexto = '${_radio.round()} m';

    return _Tarjeta(
      titulo: 'Ubicación Geolocalizada',
      etiqueta: 'Para validar asistencia',
      accion: const Icon(
        Icons.pin_drop_outlined,
        size: 18,
        color: AppColors.outline,
      ),
      children: [
        // Vista del mapa (decorativa hasta conectar la ubicación real)
        Container(
          height: 144,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surfaceLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(child: CustomPaint(painter: _PuntosPainter())),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.primaryDark.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primaryDark.withValues(alpha: 0.3),
                  ),
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryDark,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryDark.withValues(alpha: 0.2),
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.location_on,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              Positioned(
                left: 8,
                bottom: 8,
                child: _InsigniaMapa(
                  icono: Icons.radar,
                  texto: 'Radio: $radioTexto',
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: _InsigniaMapa(
                  icono: _latitud == null ? Icons.gps_off : Icons.gps_fixed,
                  texto: _latitud == null
                      ? 'Sin ubicación'
                      : '${_latitud!.toStringAsFixed(5)}, '
                            '${_longitud!.toStringAsFixed(5)}',
                ),
              ),
            ],
          ),
        ),

        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _buscandoUbicacion ? null : _fijarUbicacion,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryDark,
                side: const BorderSide(color: AppColors.primaryDark),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              icon: _buscandoUbicacion
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location, size: 16),
              label: Text(
                _latitud == null ? 'Fijar mi ubicación' : 'Actualizar ubicación',
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.radar,
                    size: 16,
                    color: AppColors.primaryDark,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Radio:',
                    style: TextStyle(color: AppColors.outline, fontSize: 11),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    radioTexto,
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // Ajuste del radio
        Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceLow.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ajustar radio de detección',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'Paso: 5m',
                    style: TextStyle(color: AppColors.outline, fontSize: 11),
                  ),
                ],
              ),
              Slider(
                value: _radio,
                min: 10,
                max: 500,
                divisions: 98, // pasos de 5 m
                activeColor: AppColors.primaryDark,
                inactiveColor: AppColors.surfaceHigh,
                label: radioTexto,
                onChanged: (v) => setState(() => _radio = v),
              ),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _MarcaRadio('10 m'),
                  _MarcaRadio('100 m'),
                  _MarcaRadio('250 m'),
                  _MarcaRadio('500 m'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- Estudiantes ----------

  Widget _buildEstudiantes() {
    return _Tarjeta(
      titulo: 'Lista de Estudiantes',
      etiqueta: 'Opcional',
      etiquetaNeutra: true,
      children: [
        InkWell(
          onTap: _elegirArchivo,
          borderRadius: BorderRadius.circular(12),
          child: CustomPaint(
            painter: _BordePunteadoPainter(color: AppColors.outlineVariant),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceLow.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.table_chart_outlined,
                      size: 24,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Cargar archivo Excel (.xlsx, .csv)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Text.rich(
                    TextSpan(
                      text: 'Arrastra el archivo o ',
                      children: [
                        TextSpan(
                          text: 'examinar',
                          style: TextStyle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.outline, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_estudiantes.isNotEmpty)
          Row(
            children: [
              const Icon(
                Icons.check_circle,
                size: 18,
                color: AppColors.primaryDark,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_estudiantes.length} estudiantes · $_nombreArchivo',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Quitar lista',
                onPressed: () => setState(() {
                  _estudiantes = [];
                  _nombreArchivo = null;
                }),
                color: AppColors.outline,
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
      ],
    );
  }
}

/// Tarjeta blanca con título en mayúsculas y contenido separado.
class _Tarjeta extends StatelessWidget {
  final String titulo;
  final String? etiqueta;
  final bool etiquetaNeutra;
  final Widget? accion;
  final List<Widget> children;

  const _Tarjeta({
    required this.titulo,
    required this.children,
    this.etiqueta,
    this.etiquetaNeutra = false,
    this.accion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  titulo.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              if (etiqueta != null) ...[
                const SizedBox(width: 8),
                _Etiqueta(etiqueta!, destacada: !etiquetaNeutra),
              ],
              const Spacer(),
              ?accion,
            ],
          ),
          for (final child in children) ...[
            const SizedBox(height: 8),
            child,
          ],
        ],
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  final String texto;
  final bool destacada;

  const _Etiqueta(this.texto, {this.destacada = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: destacada
            ? AppColors.primaryFixed.withValues(alpha: 0.4)
            : AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: destacada ? AppColors.primaryDark : AppColors.outline,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Caja tocable con una etiqueta, un ícono y un valor (o "Sin definir").
class _CajaValor extends StatelessWidget {
  final String etiqueta;
  final IconData icono;
  final Color colorIcono;
  final String? valor;
  final Color fondo;
  final VoidCallback onTap;

  const _CajaValor({
    required this.etiqueta,
    required this.icono,
    required this.colorIcono,
    required this.valor,
    required this.onTap,
    this.fondo = AppColors.surfaceLow,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: fondo,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                etiqueta,
                style: const TextStyle(
                  color: AppColors.outline,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(icono, size: 18, color: colorIcono),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      valor ?? 'Sin definir',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: valor == null
                            ? AppColors.outline
                            : AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipDia extends StatelessWidget {
  final String texto;
  final bool seleccionado;
  final VoidCallback onTap;

  const _ChipDia({
    required this.texto,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: seleccionado ? AppColors.primaryDark : AppColors.surfaceLow,
      borderRadius: BorderRadius.circular(8),
      elevation: seleccionado ? 1 : 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            texto,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: seleccionado ? Colors.white : AppColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _InsigniaMapa extends StatelessWidget {
  final IconData icono;
  final String texto;

  const _InsigniaMapa({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 14, color: AppColors.primaryDark),
          const SizedBox(width: 6),
          Text(
            texto,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MarcaRadio extends StatelessWidget {
  final String texto;

  const _MarcaRadio(this.texto);

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: const TextStyle(
        color: AppColors.outline,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// Patrón de puntos que simula el fondo de un mapa.
class _PuntosPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.primary.withValues(alpha: 0.4);
    const paso = 16.0;
    for (var x = paso / 2; x < size.width; x += paso) {
      for (var y = paso / 2; y < size.height; y += paso) {
        canvas.drawCircle(Offset(x, y), 0.8, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Borde punteado redondeado para la zona de carga de archivos.
class _BordePunteadoPainter extends CustomPainter {
  final Color color;

  _BordePunteadoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      );

    for (final metric in path.computeMetrics()) {
      var distancia = 0.0;
      while (distancia < metric.length) {
        canvas.drawPath(metric.extractPath(distancia, distancia + 6), paint);
        distancia += 10;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BordePunteadoPainter oldDelegate) =>
      oldDelegate.color != color;
}
