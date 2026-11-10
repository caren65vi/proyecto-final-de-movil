import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
// Solo LatLng: latlong2 también define un Path que choca con el de Flutter
import 'package:latlong2/latlong.dart' show LatLng;

import '../../../domain/entities/bloque_horario.dart';
import '../../../domain/entities/curso.dart';
import '../../../domain/entities/estudiante_inscrito.dart';
import '../../../domain/repositories/curso_repository.dart';
import '../../../domain/usecases/curso_usecases.dart';
import '../../theme/app_colors.dart';
import 'importar_estudiantes.dart';

/// Configuración del curso: datos generales, período, horarios y nómina.
class EditarCursoScreen extends StatefulWidget {
  const EditarCursoScreen({
    super.key,
    required this.curso,
    required this.editarCurso,
    required this.importarEstudiantes,
    required this.agregarEstudiante,
    required this.obtenerMiUbicacion,
  });

  final Curso curso;
  final EditarCurso editarCurso;
  final ImportarEstudiantes importarEstudiantes;
  final AgregarEstudiante agregarEstudiante;
  final ObtenerMiUbicacion obtenerMiUbicacion;

  @override
  State<EditarCursoScreen> createState() => _EditarCursoScreenState();
}

class _EditarCursoScreenState extends State<EditarCursoScreen> {
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
  late final _nombre = TextEditingController(text: widget.curso.nombreMateria);
  late final _aula = TextEditingController(text: widget.curso.aula);
  late String _grupo = widget.curso.numeroGrupo;
  late DateTime _inicio = widget.curso.fechaInicio;
  late DateTime _fin = widget.curso.fechaFin;
  late final List<BloqueHorario> _horario = [...widget.curso.horario];

  // Ubicación donde se valida la asistencia. Los cursos viejos sin ubicación
  // llegan con 0, 0: se toman como "sin ubicación".
  late double? _latitud = _sinUbicacion ? null : widget.curso.latitud;
  late double? _longitud = _sinUbicacion ? null : widget.curso.longitud;
  late double _radio = widget.curso.radioMetros
      .toDouble()
      .clamp(_radioMin, _radioMax)
      .toDouble();
  bool _buscandoUbicacion = false;
  final _mapController = MapController();

  static const _radioMin = 10.0;
  static const _radioMax = 500.0;

  bool get _sinUbicacion =>
      widget.curso.latitud == 0 && widget.curso.longitud == 0;

  // Archivo nuevo de estudiantes (se aplica al guardar)
  List<EstudianteInscrito> _nuevaNomina = [];
  String? _nombreArchivo;

  bool _guardando = false;

  @override
  void dispose() {
    _nombre.dispose();
    _aula.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // Toma la ubicación del GPS del celular y centra el mapa en ella
  Future<void> _usarMiUbicacion() async {
    setState(() => _buscandoUbicacion = true);
    try {
      final ubicacion = await widget.obtenerMiUbicacion();
      if (!mounted) return;
      // Si el mapa ya estaba visible hay que moverlo; si no, nace centrado
      final mapaVisible = _latitud != null;
      setState(() {
        _latitud = ubicacion.latitud;
        _longitud = ubicacion.longitud;
      });
      if (mapaVisible) {
        _mapController.move(LatLng(ubicacion.latitud, ubicacion.longitud), 17);
      }
    } on CursoError catch (e) {
      _mostrar(e.mensaje, error: true);
    } catch (_) {
      _mostrar(
        'No se pudo obtener la ubicación. Intenta de nuevo.',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _buscandoUbicacion = false);
    }
  }

  // Grupos del 1 al 10, más el actual si es otro valor
  List<String> get _grupos => {
    for (var g = 1; g <= 10; g++) '$g',
    if (_grupo.isNotEmpty) _grupo,
  }.toList();

  DateTime _soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);

  // El curso está activo si hoy cae dentro del período
  bool get _activo {
    final hoy = _soloFecha(DateTime.now());
    return !hoy.isBefore(_soloFecha(_inicio)) && !hoy.isAfter(_soloFecha(_fin));
  }

  // Ej. "2025-I (Vigente)"
  String get _periodoAcademico {
    final semestre = _inicio.month <= 6 ? 'I' : 'II';
    return '${_inicio.year}-$semestre${_activo ? ' (Vigente)' : ''}';
  }

  // Ej. "10 Feb 2025"
  String _fecha(DateTime d) => '${d.day} ${_meses[d.month - 1]} ${d.year}';

  // "07:00" → "07:00 AM"
  String _hora12(String hora) {
    final partes = hora.split(':');
    final h = int.parse(partes[0]);
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '${h12.toString().padLeft(2, '0')}:${partes[1]} '
        '${h < 12 ? 'AM' : 'PM'}';
  }

  void _mostrar(String mensaje, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: error ? AppColors.error : null,
      ),
    );
  }

  Future<void> _elegirPeriodo() async {
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(_inicio.year - 1),
      lastDate: DateTime(_fin.year + 2),
      initialDateRange: DateTimeRange(start: _inicio, end: _fin),
      helpText: 'Rango de fechas',
      saveText: 'Guardar período',
    );
    if (rango == null) return;
    setState(() {
      _inicio = rango.start;
      _fin = rango.end;
    });
  }

  // Abre el editor de un horario (null = horario nuevo)
  Future<void> _editarSesion([int? indice]) async {
    final bloque = await showDialog<BloqueHorario>(
      context: context,
      builder: (_) => _DialogoSesion(
        inicial: indice == null ? null : _horario[indice],
        hora12: _hora12,
      ),
    );
    if (bloque == null) return;
    setState(() {
      if (indice == null) {
        _horario.add(bloque);
      } else {
        _horario[indice] = bloque;
      }
      _horario.sort(
        (a, b) => a.dia != b.dia
            ? a.dia.compareTo(b.dia)
            : a.inicio.compareTo(b.inicio),
      );
    });
  }

  // Muestra el formato, lee el archivo y avisa si cargó o el error
  Future<void> _cargarArchivo() async {
    final resultado = await importarEstudiantesConFormato(
      context,
      importar: widget.importarEstudiantes,
      cuandoSeGuardan:
          'Toca "Guardar Cambios del Curso" para inscribirlos. '
          'Los que ya estaban en el curso conservan su asistencia.',
    );
    if (resultado == null || !mounted) return;
    setState(() {
      _nuevaNomina = resultado.estudiantes;
      _nombreArchivo = resultado.nombreArchivo;
    });
  }

  void _eliminarArchivo() => setState(() {
    _nuevaNomina = [];
    _nombreArchivo = null;
  });

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_latitud == null || _longitud == null) {
      _mostrar(
        'Fija la ubicación del curso para validar la asistencia',
        error: true,
      );
      return;
    }

    // Se copia el curso cambiando solo lo que se editó
    final c = widget.curso;
    final editado = Curso(
      id: c.id,
      nombreMateria: _nombre.text.trim(),
      facultad: c.facultad,
      numeroGrupo: _grupo,
      aula: _aula.text.trim(),
      docenteUid: c.docenteUid,
      docenteNombre: c.docenteNombre,
      fechaInicio: _inicio,
      fechaFin: _fin,
      horario: _horario,
      latitud: _latitud!,
      longitud: _longitud!,
      radioMetros: _radio.round(),
      metaAsistencia: c.metaAsistencia,
      totalEstudiantes: c.totalEstudiantes,
    );

    setState(() => _guardando = true);
    try {
      await widget.editarCurso(editado);

      // Del archivo nuevo solo se agregan los que aún no están inscritos;
      // los que ya estaban conservan sus horas de asistencia.
      var agregados = 0;
      for (final e in _nuevaNomina) {
        try {
          await widget.agregarEstudiante(
            c.id!,
            correo: e.correo,
            nombre: e.nombre,
            codigo: e.codigoEstudiante,
          );
          agregados++;
        } on CursoError {
          // Ya inscrito o correo no válido: se omite
        }
      }

      if (!mounted) return;
      _mostrar(
        _nuevaNomina.isEmpty
            ? 'Cambios guardados'
            : 'Cambios guardados · $agregados estudiantes nuevos',
      );
      Navigator.pop(context);
    } on CursoError catch (e) {
      _mostrar(e.mensaje, error: true);
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
              'Editar Curso',
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
            _buildEncabezado(),
            const SizedBox(height: 16),
            _buildInformacion(),
            const SizedBox(height: 16),
            _buildDuracion(),
            const SizedBox(height: 16),
            _buildHorarios(),
            const SizedBox(height: 16),
            _buildUbicacion(),
            const SizedBox(height: 16),
            _buildNomina(),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _guardando ? null : _guardar,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                icon: _guardando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined, size: 20),
                label: const Text('Guardar Cambios del Curso'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _guardando ? null : () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.surfaceContainer,
                  foregroundColor: AppColors.textSecondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Descartar Modificaciones'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Ubicación ----------

  Widget _buildUbicacion() {
    final radioTexto = '${_radio.round()} m';
    final hayUbicacion = _latitud != null && _longitud != null;

    return _Tarjeta(
      icono: Icons.pin_drop_outlined,
      titulo: 'Ubicación',
      accion: TextButton.icon(
        onPressed: _buscandoUbicacion ? null : _usarMiUbicacion,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
          visualDensity: VisualDensity.compact,
          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        icon: _buscandoUbicacion
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.my_location, size: 16),
        label: Text(hayUbicacion ? 'Usar mi ubicación' : 'Fijar ubicación'),
      ),
      children: [
        Container(
          height: 220,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surfaceLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: hayUbicacion
              ? _buildMapa()
              : const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.gps_off, size: 32, color: AppColors.outline),
                      SizedBox(height: 8),
                      Text(
                        'Este curso no tiene ubicación.\n'
                        'Toca "Fijar ubicación" estando en el salón.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 6),
        Text(
          hayUbicacion
              ? '${_latitud!.toStringAsFixed(5)}, '
                    '${_longitud!.toStringAsFixed(5)} · '
                    'Toca el mapa para mover el punto.'
              : 'Sin ubicación',
          style: const TextStyle(color: AppColors.outline, fontSize: 11),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(child: _Rotulo('Radio de detección')),
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
        Slider(
          value: _radio,
          min: _radioMin,
          max: _radioMax,
          divisions: 98, // pasos de 5 m
          activeColor: AppColors.primaryDark,
          inactiveColor: AppColors.surfaceHigh,
          label: radioTexto,
          onChanged: (v) => setState(() => _radio = v),
        ),
      ],
    );
  }

  // Mapa de OpenStreetMap con el punto del curso y el radio a escala
  Widget _buildMapa() {
    final centro = LatLng(_latitud!, _longitud!);
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: centro,
        initialZoom: 17,
        minZoom: 3,
        maxZoom: 19,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        // Tocar el mapa mueve el punto del curso
        onTap: (_, punto) => setState(() {
          _latitud = punto.latitude;
          _longitud = punto.longitude;
        }),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          // OpenStreetMap pide identificar la app que descarga los mapas
          userAgentPackageName: 'com.example.ceiba',
        ),
        CircleLayer(
          circles: [
            CircleMarker(
              point: centro,
              radius: _radio,
              useRadiusInMeter: true,
              color: AppColors.primaryDark.withValues(alpha: 0.15),
              borderColor: AppColors.primaryDark.withValues(alpha: 0.6),
              borderStrokeWidth: 2,
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: centro,
              width: 36,
              height: 36,
              child: const Icon(
                Icons.location_on,
                size: 36,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ),
        // Crédito obligatorio de OpenStreetMap
        const Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: EdgeInsets.all(4),
            child: DecoratedBox(
              decoration: BoxDecoration(color: Color(0xCCFFFFFF)),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                child: Text(
                  '© OpenStreetMap',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 9),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------- Encabezado ----------

  Widget _buildEncabezado() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GESTIÓN ACADÉMICA',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                'Configuración del Curso',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.24,
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _activo
                ? AppColors.primaryFixed
                : AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.circle,
                size: 7,
                color: _activo ? AppColors.primary : AppColors.outline,
              ),
              const SizedBox(width: 5),
              Text(
                _activo ? 'Activo' : 'Inactivo',
                style: TextStyle(
                  color: _activo ? AppColors.primary : AppColors.outline,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- Información general ----------

  Widget _buildInformacion() {
    return _Tarjeta(
      icono: Icons.menu_book_outlined,
      titulo: 'Información General',
      children: [
        const _Rotulo('Nombre de la Asignatura'),
        TextFormField(
          controller: _nombre,
          textCapitalization: TextCapitalization.sentences,
          decoration: _decoracion(Icons.school_outlined),
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Escribe el nombre de la asignatura'
              : null,
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Rotulo('Grupo'),
                  DropdownButtonFormField<String>(
                    initialValue: _grupo.isEmpty ? null : _grupo,
                    isExpanded: true,
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: AppColors.textSecondary,
                    ),
                    decoration: _decoracion(Icons.tag),
                    items: [
                      for (final g in _grupos)
                        DropdownMenuItem(value: g, child: Text('Grupo $g')),
                    ],
                    onChanged: (v) => setState(() => _grupo = v ?? _grupo),
                    validator: (v) => v == null ? 'Elige el grupo' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Rotulo('Aula Asignada'),
                  TextFormField(
                    controller: _aula,
                    decoration: _decoracion(Icons.meeting_room_outlined),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const _Rotulo('Periodo Académico'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 18,
                color: AppColors.outline,
              ),
              const SizedBox(width: 10),
              Text(
                _periodoAcademico,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  InputDecoration _decoracion(IconData icono) {
    final borde = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    );
    return InputDecoration(
      prefixIcon: Icon(icono, size: 20, color: AppColors.outline),
      filled: true,
      fillColor: AppColors.surfaceLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: borde,
      enabledBorder: borde,
      focusedBorder: borde.copyWith(
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }

  // ---------- Duración ----------

  Widget _buildDuracion() {
    return _Tarjeta(
      icono: Icons.calendar_month_outlined,
      titulo: 'Duración de Clases',
      accion: TextButton.icon(
        onPressed: _elegirPeriodo,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
          visualDensity: VisualDensity.compact,
          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        icon: const Icon(Icons.edit_calendar_outlined, size: 16),
        label: const Text('Editar periodo'),
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: _CajaFecha(
                etiqueta: 'Inicio',
                icono: Icons.event,
                colorIcono: AppColors.primaryDark,
                valor: _fecha(_inicio),
                onTap: _elegirPeriodo,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _CajaFecha(
                etiqueta: 'Fin',
                icono: Icons.event_busy,
                colorIcono: AppColors.attendanceWarningText,
                valor: _fecha(_fin),
                onTap: _elegirPeriodo,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------- Horarios ----------

  Widget _buildHorarios() {
    final n = _horario.length;
    return _Tarjeta(
      icono: Icons.edit_calendar_outlined,
      titulo: 'Horarios de Sesión',
      accion: Text(
        n == 1 ? '1 sesión/sem' : '$n sesiones/sem',
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      children: [
        for (var i = 0; i < _horario.length; i++) ...[
          _FilaSesion(
            letra: _diasLargos[_horario[i].dia - 1][0],
            dia: _diasLargos[_horario[i].dia - 1],
            horas:
                '${_hora12(_horario[i].inicio)} - '
                '${_hora12(_horario[i].fin)}',
            destacada: i.isEven,
            onEditar: () => _editarSesion(i),
            onEliminar: () => setState(() => _horario.removeAt(i)),
          ),
          const SizedBox(height: 8),
        ],
        if (_horario.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Agrega al menos un horario de clase',
              style: TextStyle(color: AppColors.attendanceWarningText),
            ),
          ),
        SizedBox(
          height: 44,
          child: FilledButton.icon(
            onPressed: () => _editarSesion(),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.surfaceContainer,
              foregroundColor: AppColors.textPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: const Text('Agregar nuevo horario de sesión'),
          ),
        ),
      ],
    );
  }

  // ---------- Nómina ----------

  Widget _buildNomina() {
    final hayArchivo = _nombreArchivo != null;

    return _Tarjeta(
      icono: Icons.group_add_outlined,
      titulo: 'Nómina de Estudiantes',
      accion: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primaryFixed,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'Excel Sync',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.table_chart_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hayArchivo
                              ? _nombreArchivo!
                              : 'Nómina actual del curso',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          hayArchivo
                              ? '${_nuevaNomina.length} estudiantes en el archivo'
                              : '${widget.curso.totalEstudiantes} '
                                    'estudiantes inscritos',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hayArchivo) ...[
                    const Icon(
                      Icons.check_circle_outline,
                      color: AppColors.primaryDark,
                      size: 20,
                    ),
                    IconButton(
                      tooltip: 'Quitar archivo',
                      onPressed: _eliminarArchivo,
                      color: AppColors.secondary,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.delete_outline, size: 20),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Al cargar un archivo se agregan los estudiantes nuevos '
                        'y se mantienen las asistencias históricas.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 46,
                child: FilledButton.icon(
                  onPressed: _guardando ? null : _cargarArchivo,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                  label: const Text('Cargar nuevo archivo'),
                ),
              ),
              if (hayArchivo) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: _guardando ? null : _eliminarArchivo,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.secondary,
                      side: const BorderSide(color: AppColors.secondary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Eliminar archivo'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ---------- Widgets ----------

/// Tarjeta blanca con icono, título y una acción opcional a la derecha.
class _Tarjeta extends StatelessWidget {
  const _Tarjeta({
    required this.icono,
    required this.titulo,
    required this.children,
    this.accion,
  });

  final IconData icono;
  final String titulo;
  final Widget? accion;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
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
              Icon(icono, size: 20, color: AppColors.textPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ?accion,
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

/// Texto pequeño encima de cada campo.
class _Rotulo extends StatelessWidget {
  const _Rotulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        texto,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Caja tocable con etiqueta, icono y fecha.
class _CajaFecha extends StatelessWidget {
  const _CajaFecha({
    required this.etiqueta,
    required this.icono,
    required this.colorIcono,
    required this.valor,
    required this.onTap,
  });

  final String etiqueta;
  final IconData icono;
  final Color colorIcono;
  final String valor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceLow,
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
                      valor,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
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

/// Un horario semanal: letra del día, nombre, horas y acciones.
class _FilaSesion extends StatelessWidget {
  const _FilaSesion({
    required this.letra,
    required this.dia,
    required this.horas,
    required this.destacada,
    required this.onEditar,
    required this.onEliminar,
  });

  final String letra;
  final String dia;
  final String horas;
  final bool destacada; // alterna el color de la letra
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: destacada
                  ? AppColors.surfaceContainer
                  : AppColors.tertiaryFixed,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              letra,
              style: TextStyle(
                color: destacada
                    ? AppColors.textPrimary
                    : AppColors.onTertiaryContainer,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dia,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  horas,
                  style: const TextStyle(
                    color: AppColors.outline,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Editar horario',
            onPressed: onEditar,
            color: AppColors.textSecondary,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.edit_outlined, size: 18),
          ),
          IconButton(
            tooltip: 'Eliminar horario',
            onPressed: onEliminar,
            color: AppColors.textSecondary,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.delete_outline, size: 18),
          ),
        ],
      ),
    );
  }
}

/// Diálogo para crear o cambiar un horario: día y rango de horas.
class _DialogoSesion extends StatefulWidget {
  const _DialogoSesion({required this.inicial, required this.hora12});

  final BloqueHorario? inicial;
  final String Function(String) hora12;

  @override
  State<_DialogoSesion> createState() => _DialogoSesionState();
}

class _DialogoSesionState extends State<_DialogoSesion> {
  static const _dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];

  late int _dia = widget.inicial?.dia ?? 1;
  late String? _desde = widget.inicial?.inicio;
  late String? _hasta = widget.inicial?.fin;
  String? _error;

  TimeOfDay _aTime(String? hora, int porDefecto) {
    if (hora == null) return TimeOfDay(hour: porDefecto, minute: 0);
    final p = hora.split(':');
    return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }

  String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';

  Future<void> _elegir({required bool esDesde}) async {
    final hora = await showTimePicker(
      context: context,
      initialTime: esDesde ? _aTime(_desde, 7) : _aTime(_hasta, 9),
      helpText: esDesde ? 'Hora de inicio' : 'Hora de fin',
    );
    if (hora == null) return;
    setState(() {
      if (esDesde) {
        _desde = _hhmm(hora);
      } else {
        _hasta = _hhmm(hora);
      }
      _error = null;
    });
  }

  void _confirmar() {
    if (_desde == null || _hasta == null) {
      setState(() => _error = 'Elige la hora de inicio y de fin');
      return;
    }
    // "HH:mm" se puede comparar como texto
    if (_hasta!.compareTo(_desde!) <= 0) {
      setState(() => _error = 'La hora de fin debe ser posterior al inicio');
      return;
    }
    Navigator.pop(
      context,
      BloqueHorario(dia: _dia, inicio: _desde!, fin: _hasta!),
    );
  }

  Widget _botonHora(String etiqueta, String? valor, VoidCallback onTap) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.outlineVariant),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Column(
          children: [
            Text(
              etiqueta,
              style: const TextStyle(color: AppColors.outline, fontSize: 11),
            ),
            Text(
              valor == null ? '--:--' : widget.hora12(valor),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.inicial == null ? 'Nuevo horario' : 'Editar horario'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < _dias.length; i++)
                ChoiceChip(
                  label: Text(_dias[i]),
                  selected: _dia == i + 1,
                  showCheckmark: false,
                  selectedColor: AppColors.primaryDark,
                  labelStyle: TextStyle(
                    color: _dia == i + 1 ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: (_) => setState(() => _dia = i + 1),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _botonHora('Desde', _desde, () => _elegir(esDesde: true)),
              const SizedBox(width: 8),
              _botonHora('Hasta', _hasta, () => _elegir(esDesde: false)),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _confirmar,
          style: FilledButton.styleFrom(backgroundColor: AppColors.primaryDark),
          child: const Text('Listo'),
        ),
      ],
    );
  }
}
