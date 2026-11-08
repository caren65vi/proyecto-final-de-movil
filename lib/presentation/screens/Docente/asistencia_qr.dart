import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../domain/entities/asistencia.dart';
import '../../../domain/entities/curso.dart';
import '../../../domain/entities/estudiante_inscrito.dart';
import '../../../domain/repositories/asistencia_repository.dart';
import '../../../domain/repositories/curso_repository.dart';
import '../../../domain/usecases/asistencia_usecases.dart';
import '../../../domain/usecases/curso_usecases.dart';
import '../../theme/app_colors.dart';

const _logo = 'assets/images/ceiba_logo.png';
const _rojoCierre = Color(0xFF9E3B2A);

// Registros que se ven antes de pulsar "Ver los N ..."
const _itemsVisibles = 4;

/// El docente muestra el QR y ve en vivo quién va registrando asistencia.
///
/// Si sale de la pantalla sin cerrar, la sesión queda abierta; al volver a
/// entrar se retoma la misma.
class AsistenciaQrScreen extends StatefulWidget {
  const AsistenciaQrScreen({
    super.key,
    required this.curso,
    required this.asistenciaRepository,
    required this.cursoRepository,
  });

  final Curso curso;
  final AsistenciaRepository asistenciaRepository;

  /// Para la lista de inscritos (pestaña "Pendientes").
  final CursoRepository cursoRepository;

  @override
  State<AsistenciaQrScreen> createState() => _AsistenciaQrScreenState();
}

class _AsistenciaQrScreenState extends State<AsistenciaQrScreen>
    with SingleTickerProviderStateMixin {
  late final _abrir = AbrirSesion(widget.asistenciaRepository);
  late final _renovar = RenovarQR(widget.asistenciaRepository);
  late final _cerrar = CerrarAsistencia(widget.asistenciaRepository);
  late final _obtenerAsistencias = ObtenerAsistencias(
    widget.asistenciaRepository,
  );
  late final _escucharToken = EscucharTokenQR(widget.asistenciaRepository);
  late final _obtenerEstudiantes = ObtenerEstudiantes(widget.cursoRepository);

  late final AnimationController _pulso = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);
  late final Animation<double> _opacidadPulso = Tween<double>(
    begin: 0.3,
    end: 1,
  ).animate(_pulso);

  // Texto del QR y si está en pausa; los comparten esta pantalla y la
  // vista proyectada
  final _qrData = ValueNotifier<String?>(null);
  final _pausado = ValueNotifier<bool>(false);

  final _subs = <StreamSubscription<Object?>>[];

  String? _sesionId;
  String? _errorCarga;
  List<Asistencia> _asistencias = const [];
  List<EstudianteInscrito> _inscritos = const [];

  bool _verPendientes = false;
  bool _expandido = false;
  bool _cerrando = false;
  String? _error;

  String get _grupoId => widget.curso.id!;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _pulso.dispose();
    _qrData.dispose();
    _pausado.dispose();
    super.dispose();
  }

  Future<void> _iniciar() async {
    try {
      final sesion = await _abrir(_grupoId);
      if (!mounted) return;
      setState(() => _sesionId = sesion.sesionId);
      _mostrarToken(sesion.token);
      _escuchar(sesion.sesionId);
    } on AsistenciaError catch (e) {
      if (mounted) setState(() => _errorCarga = e.mensaje);
    }
  }

  void _mostrarToken(String token) {
    _qrData.value = RegistrarAsistenciaQR.contenido(
      _grupoId,
      _sesionId!,
      token,
    );
  }

  void _escuchar(String sesionId) {
    void fallo(Object error) {
      if (mounted) setState(() => _errorCarga = '$error');
    }

    _subs.addAll([
      // Cada QR sirve para un solo estudiante: cuando alguien registra su
      // asistencia, el servidor cambia el token y aquí llega el código nuevo
      // para el siguiente. Quien escanee el código viejo recibe
      // "El código QR ya fue usado".
      _escucharToken(_grupoId, sesionId).listen(_mostrarToken, onError: fallo),
      _obtenerAsistencias(_grupoId, sesionId).listen(
        (lista) => setState(() => _asistencias = lista),
        onError: fallo,
      ),
      _obtenerEstudiantes(_grupoId).listen(
        (lista) => setState(() => _inscritos = lista),
        onError: fallo,
      ),
    ]);
  }

  // ---------- Datos derivados ----------

  Map<String, EstudianteInscrito> get _inscritosPorCorreo => {
    for (final e in _inscritos) e.correo: e,
  };

  List<_Fila> _escaneados() {
    final porCorreo = _inscritosPorCorreo;
    final filas = [
      for (final a in _asistencias)
        if (a.presente) _fila(a.correo, a.nombre, a.registradaEn, porCorreo),
    ];
    // En orden de llegada; la hora del servidor puede llegar vacía un instante
    filas.sort((a, b) {
      if (a.hora == null) return 1;
      if (b.hora == null) return -1;
      return a.hora!.compareTo(b.hora!);
    });
    return filas;
  }

  List<_Fila> _pendientes() {
    final porCorreo = _inscritosPorCorreo;
    final registrados = {for (final a in _asistencias) a.correo};
    final filas = [
      for (final e in _inscritos)
        if (!registrados.contains(e.correo))
          _fila(e.correo, e.nombre, null, porCorreo),
    ];
    filas.sort(
      (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
    );
    return filas;
  }

  _Fila _fila(
    String correo,
    String nombre,
    DateTime? hora,
    Map<String, EstudianteInscrito> porCorreo,
  ) {
    final inscrito = porCorreo[correo];
    var nombreFinal = nombre.trim();
    if (nombreFinal.isEmpty) nombreFinal = inscrito?.nombre.trim() ?? '';
    final codigo = inscrito?.codigoEstudiante?.trim() ?? '';
    return _Fila(
      nombre: nombreFinal.isEmpty ? correo : nombreFinal,
      codigo: codigo.isEmpty ? correo : codigo,
      hora: hora,
    );
  }

  // ---------- Acciones ----------

  Future<void> _alternarPausa() async {
    if (_pausado.value) {
      setState(() => _pausado.value = false);
      return;
    }
    setState(() {
      _pausado.value = true;
      _error = null;
    });
    // Se cambia el token para que nadie use una foto del código que estaba
    // en pantalla mientras el escaneo está en pausa
    try {
      await _renovar(_grupoId, _sesionId!);
    } on AsistenciaError {
      if (mounted) {
        setState(
          () => _error =
              'El QR está oculto, pero no se pudo renovar el código anterior.',
        );
      }
    }
  }

  Future<void> _cerrarAsistencia(int pendientes) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar la asistencia?'),
        content: Text(
          pendientes == 0
              ? 'Se sellará la sesión. Esta acción no se puede deshacer.'
              : 'Los $pendientes estudiantes que no escanearon quedarán como '
                    'ausentes. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _rojoCierre),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar y sellar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    setState(() {
      _cerrando = true;
      _error = null;
    });
    try {
      await _cerrar(_grupoId, _sesionId!);
      if (!mounted) return;
      Navigator.pop(context, true);
    } on AsistenciaError catch (e) {
      if (!mounted) return;
      setState(() => _cerrando = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }

  void _proyectar() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _QrProyectado(
          datos: _qrData,
          pausado: _pausado,
          titulo: widget.curso.nombreMateria,
          subtitulo: _subtituloGrupo,
        ),
      ),
    );
  }

  // ---------- Vista ----------

  String get _subtituloGrupo {
    final materia = widget.curso.nombreMateria.trim();
    final numero = widget.curso.numeroGrupo.trim();
    return [
      if (materia.isNotEmpty) materia,
      if (numero.isNotEmpty) 'Grupo $numero',
    ].join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Salir',
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(_logo, width: 32, height: 32),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Asistencia En Vivo',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_subtituloGrupo.isNotEmpty)
                    Text(
                      _subtituloGrupo,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _cuerpo(),
    );
  }

  Widget _cuerpo() {
    if (_errorCarga != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 36),
              const SizedBox(height: 12),
              Text(_errorCarga!, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    if (_sesionId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final escaneados = _escaneados();
    final pendientes = _pendientes();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        _tarjetaEstado(escaneados.length),
        const SizedBox(height: 16),
        _tarjetaQr(),
        const SizedBox(height: 24),
        _encabezadoRegistro(escaneados.length),
        const SizedBox(height: 12),
        _selectorPestanas(escaneados.length, pendientes.length),
        const SizedBox(height: 12),
        ..._lista(_verPendientes ? pendientes : escaneados),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.error),
          ),
        ],
        const SizedBox(height: 16),
        _botonPausa(),
        const SizedBox(height: 12),
        _botonCerrar(pendientes.length),
      ],
    );
  }

  Widget _tarjetaEstado(int presentes) {
    final total = _inscritos.isNotEmpty
        ? _inscritos.length
        : widget.curso.totalEstudiantes;
    final avance = total == 0 ? 0.0 : (presentes / total).clamp(0.0, 1.0);
    final bloque = widget.curso.bloqueEnCurso();
    final horario = bloque == null
        ? null
        : _rangoHorario(bloque.inicio, bloque.fin);
    var aula = widget.curso.aula.trim();
    if (aula.isNotEmpty && !aula.toLowerCase().startsWith('aula')) {
      aula = 'Aula $aula';
    }

    return _Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.attendancePresent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FadeTransition(
                        opacity: _opacidadPulso,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          horario == null ? 'EN VIVO' : 'EN VIVO • $horario',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (aula.isNotEmpty) ...[
                const SizedBox(width: 8),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    aula,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$presentes',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                ' / $total estudiantes',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Text(
                '${(avance * 100).round()}% asistido',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: avance,
              minHeight: 8,
              backgroundColor: AppColors.surfaceContainer,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaQr() {
    return _Tarjeta(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceLow,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: AppColors.surfaceContainer),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 16,
                  color: AppColors.primary,
                ),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Código Dinámico • Token de Uso Único',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _VistaQr(datos: _qrData, pausado: _pausado),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _proyectar,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.present_to_all, size: 20),
              label: const Text(
                'Proyectar QR en Pantalla',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _encabezadoRegistro(int escaneados) {
    return Row(
      children: [
        const Text(
          'Registro en Vivo',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primaryDark,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            '$escaneados',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _selectorPestanas(int escaneados, int pendientes) {
    void elegir(bool verPendientes) => setState(() {
      _verPendientes = verPendientes;
      _expandido = false;
    });

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _Pestana(
            texto: 'Escaneados ($escaneados)',
            activa: !_verPendientes,
            onTap: () => elegir(false),
          ),
          _Pestana(
            texto: 'Pendientes ($pendientes)',
            activa: _verPendientes,
            onTap: () => elegir(true),
          ),
        ],
      ),
    );
  }

  List<Widget> _lista(List<_Fila> filas) {
    if (filas.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
          child: Text(
            _verPendientes
                ? 'Todos los estudiantes ya registraron su asistencia.'
                : 'Aún no hay escaneos. Los registros aparecerán aquí en tiempo real.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ];
    }

    final visibles = _expandido ? filas : filas.take(_itemsVisibles);
    return [
      for (final fila in visibles)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _TarjetaEstudiante(fila: fila, pendiente: _verPendientes),
        ),
      if (filas.length > _itemsVisibles)
        Center(
          child: TextButton(
            onPressed: () => setState(() => _expandido = !_expandido),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _expandido
                      ? 'Mostrar menos'
                      : _verPendientes
                      ? 'Ver los ${filas.length} estudiantes pendientes'
                      : 'Ver los ${filas.length} escaneos registrados',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _expandido ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
    ];
  }

  Widget _botonPausa() {
    final pausado = _pausado.value;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _cerrando ? null : _alternarPausa,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.surfaceContainer,
          foregroundColor: AppColors.primaryDark,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: Icon(
          pausado ? Icons.play_circle_outline : Icons.pause_circle_outline,
        ),
        label: Text(
          pausado ? 'Reanudar Escaneo QR' : 'Pausar Escaneo QR',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _botonCerrar(int pendientes) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _cerrando ? null : () => _cerrarAsistencia(pendientes),
        style: FilledButton.styleFrom(
          backgroundColor: _rojoCierre,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _rojoCierre.withAlpha(150),
          disabledForegroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: _cerrando
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.lock_outline),
        label: const Text(
          'Cerrar Asistencia y Sellar Sesión',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// ---------- Utilidades de formato ----------

// "07:00", "09:00" -> "07:00 - 09:00 AM"
String? _rangoHorario(String inicio, String fin) {
  final a = _hora12Texto(inicio);
  final b = _hora12Texto(fin);
  if (a == null || b == null) return null;
  if (a.periodo == b.periodo) return '${a.hora} - ${b.hora} ${b.periodo}';
  return '${a.hora} ${a.periodo} - ${b.hora} ${b.periodo}';
}

({String hora, String periodo})? _hora12Texto(String texto) {
  final partes = texto.split(':');
  if (partes.length < 2) return null;
  final h = int.tryParse(partes[0]);
  final m = int.tryParse(partes[1]);
  if (h == null || m == null) return null;
  return _hora12(h, m);
}

({String hora, String periodo}) _hora12(int h, int m) {
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return (
    hora: '${h12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}',
    periodo: h < 12 ? 'AM' : 'PM',
  );
}

// "Alvarado Méndez, Sofía" -> "AM"
String _iniciales(String nombre) {
  final palabras = nombre
      .replaceAll(',', ' ')
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .take(2);
  final letras = palabras.map((p) => p[0].toUpperCase()).join();
  return letras.isEmpty ? '?' : letras;
}

// ---------- Widgets ----------

class _Fila {
  const _Fila({required this.nombre, required this.codigo, this.hora});

  final String nombre;
  final String codigo;
  final DateTime? hora;
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceContainer),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// El QR con el logo al centro; se tapa cuando el escaneo está en pausa.
class _VistaQr extends StatelessWidget {
  const _VistaQr({
    required this.datos,
    required this.pausado,
    this.tamanoLogo = 52,
  });

  final ValueNotifier<String?> datos;
  final ValueNotifier<bool> pausado;
  final double tamanoLogo;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceLow,
          borderRadius: BorderRadius.circular(20),
        ),
        child: ListenableBuilder(
          listenable: Listenable.merge([datos, pausado]),
          builder: (context, _) {
            final data = datos.value;
            if (data == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return Stack(
              alignment: Alignment.center,
              children: [
                QrImageView(
                  data: data,
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.transparent,
                  // Alta corrección de errores para que el logo no estorbe
                  errorCorrectionLevel: QrErrorCorrectLevel.H,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: AppColors.primary,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: AppColors.primary,
                  ),
                ),
                Container(
                  width: tamanoLogo,
                  height: tamanoLogo,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surfaceLow, width: 4),
                  ),
                  child: ClipOval(
                    child: Image.asset(_logo, fit: BoxFit.contain),
                  ),
                ),
                if (pausado.value)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.pause_circle_outline,
                            size: 48,
                            color: AppColors.primary,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Escaneo en pausa',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Reanuda para mostrar el código',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Pestana extends StatelessWidget {
  const _Pestana({
    required this.texto,
    required this.activa,
    required this.onTap,
  });

  final String texto;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: activa ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: activa
                ? const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              texto,
              style: TextStyle(
                color: activa ? AppColors.textPrimary : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: activa ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TarjetaEstudiante extends StatelessWidget {
  const _TarjetaEstudiante({required this.fila, required this.pendiente});

  final _Fila fila;
  final bool pendiente;

  @override
  Widget build(BuildContext context) {
    var detalle = 'ID: ${fila.codigo}';
    if (!pendiente) {
      final hora = fila.hora;
      if (hora == null) {
        detalle += ' • ahora';
      } else {
        final h = _hora12(hora.hour, hora.minute);
        detalle += ' • ${h.hora} ${h.periodo}';
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceContainer),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: pendiente
                ? AppColors.surfaceContainer
                : AppColors.attendancePresent,
            child: Text(
              _iniciales(fila.nombre),
              style: TextStyle(
                color: pendiente
                    ? AppColors.attendanceAbsentText
                    : AppColors.primary,
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
                  fila.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detalle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.surfaceLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  pendiente ? Icons.schedule : Icons.check_circle,
                  size: 16,
                  color: pendiente ? AppColors.outline : AppColors.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  pendiente ? 'Pendiente' : 'Verificado',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// QR a pantalla completa para proyectarlo en el salón.
class _QrProyectado extends StatelessWidget {
  const _QrProyectado({
    required this.datos,
    required this.pausado,
    required this.titulo,
    required this.subtitulo,
  });

  final ValueNotifier<String?> datos;
  final ValueNotifier<bool> pausado;
  final String titulo;
  final String subtitulo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Cerrar',
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: [
                  if (titulo.isNotEmpty)
                    Text(
                      titulo,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  if (subtitulo.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitulo,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _VistaQr(datos: datos, pausado: pausado, tamanoLogo: 72),
                  const SizedBox(height: 20),
                  const Text(
                    'Escanea este código con la app Ceiba para registrar tu asistencia',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
