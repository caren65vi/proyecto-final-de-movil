import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../domain/entities/curso.dart';
import '../../../domain/repositories/asistencia_repository.dart';
import '../../../domain/usecases/asistencia_usecases.dart';
import '../../theme/app_colors.dart';

const _logo = 'assets/images/ceiba_logo.png';

/// El estudiante escanea el QR del docente para registrar su asistencia.
///
/// Cada QR sirve para un solo estudiante: si alguien ya lo usó, el servidor
/// responde "El código QR ya fue usado" y ese mensaje llega hasta aquí a
/// través del repositorio (AsistenciaError).
class EscanearQrScreen extends StatefulWidget {
  const EscanearQrScreen({
    super.key,
    required this.asistenciaRepository,
    this.cursos = const [],
  });

  final AsistenciaRepository asistenciaRepository;

  /// Cursos del estudiante; se usan para mostrar la clase en curso.
  final List<Curso> cursos;

  @override
  State<EscanearQrScreen> createState() => _EscanearQrScreenState();
}

class _EscanearQrScreenState extends State<EscanearQrScreen>
    with SingleTickerProviderStateMixin {
  late final _registrar = RegistrarAsistenciaQR(widget.asistenciaRepository);
  final _camara = MobileScannerController();
  late final AnimationController _linea = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  late final Curso? _claseEnCurso = widget.cursos
      .where((c) => c.bloqueEnCurso() != null)
      .firstOrNull;

  bool _procesando = false;

  @override
  void dispose() {
    _camara.dispose();
    _linea.dispose();
    super.dispose();
  }

  Future<void> _alDetectar(BarcodeCapture captura) async {
    if (_procesando || captura.barcodes.isEmpty) return;
    final contenido = captura.barcodes.first.rawValue;
    if (contenido == null) return;

    // Se detiene la cámara para no leer el mismo QR varias veces
    setState(() => _procesando = true);
    await _camara.stop();

    var exito = false;
    String mensaje;
    try {
      await _registrar(contenido);
      exito = true;
      mensaje = '¡Asistencia registrada!';
    } on AsistenciaError catch (e) {
      mensaje = e.mensaje;
    }
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          exito ? Icons.check_circle : Icons.error_outline,
          color: exito ? AppColors.primary : AppColors.error,
          size: 48,
        ),
        content: Text(mensaje, textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    if (!mounted) return;

    if (exito) {
      Navigator.pop(context, true);
    } else {
      setState(() => _procesando = false);
      await _camara.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final curso = _claseEnCurso;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(_logo, width: 36, height: 36),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (curso != null)
                    Text(
                      curso.nombreMateria,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const Text(
                    'Escanear Asistencia',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _tarjetaClase(curso),
          const SizedBox(height: 16),
          _visor(),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.surfaceContainer),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 16,
                  color: AppColors.primary,
                ),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Geolocalización activa en campus universitario',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.surfaceContainer,
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.arrow_back, size: 20),
              label: const Text(
                'Regresar',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaClase(Curso? curso) {
    var aula = curso?.aula.trim() ?? '';
    if (aula.isNotEmpty && !aula.toLowerCase().startsWith('aula')) {
      aula = 'Aula $aula';
    }
    final detalle = curso == null
        ? ''
        : [
            if (curso.numeroGrupo.trim().isNotEmpty)
              'Grupo ${curso.numeroGrupo.trim()}',
            if (curso.docenteNombre.trim().isNotEmpty)
              'Prof. ${curso.docenteNombre.trim()}',
          ].join(' • ');

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: curso == null ? AppColors.outline : AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                curso == null ? 'SIN CLASE EN CURSO' : 'CLASE EN CURSO',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              if (aula.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        aula,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            curso?.nombreMateria ?? 'Registro de asistencia',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (detalle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              detalle,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceLow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.qr_code_scanner, size: 20, color: AppColors.primary),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Apunta tu cámara directamente al código QR proyectado '
                    'en la pantalla por el docente.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _visor() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
        aspectRatio: 1.05,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Colors.black),
            MobileScanner(controller: _camara, onDetect: _alDetectar),
            // Oscurece la imagen para que resalten el marco y el texto
            const ColoredBox(color: Color(0x59000000)),
            LayoutBuilder(
              builder: (context, constraints) {
                final lado = constraints.biggest.shortestSide * 0.66;
                return Center(
                  child: SizedBox(
                    width: lado,
                    height: lado,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(painter: _EsquinasPainter()),
                        ),
                        if (!_procesando)
                          AnimatedBuilder(
                            animation: _linea,
                            builder: (context, _) => Positioned(
                              left: 16,
                              right: 16,
                              top: 12 + (lado - 24) * _linea.value,
                              child: Container(
                                height: 2,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.primaryFixed.withAlpha(0),
                                      AppColors.primaryFixed.withAlpha(200),
                                      AppColors.primaryFixed.withAlpha(0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _procesando
                                  ? const SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.center_focus_weak,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                              const SizedBox(height: 8),
                              Text(
                                _procesando
                                    ? 'Registrando asistencia...'
                                    : 'Buscando código QR...',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ValueListenableBuilder<MobileScannerState>(
                    valueListenable: _camara,
                    builder: (context, estado, _) {
                      final encendida = estado.torchState == TorchState.on;
                      return _BotonCamara(
                        tooltip: encendida
                            ? 'Apagar linterna'
                            : 'Encender linterna',
                        icono: encendida
                            ? Icons.flashlight_on
                            : Icons.flashlight_off,
                        activo: encendida,
                        onPressed:
                            _procesando ||
                                estado.torchState == TorchState.unavailable
                            ? null
                            : _camara.toggleTorch,
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  _BotonCamara(
                    tooltip: 'Cambiar cámara',
                    icono: Icons.cameraswitch_outlined,
                    onPressed: _procesando ? null : _camara.switchCamera,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BotonCamara extends StatelessWidget {
  const _BotonCamara({
    required this.tooltip,
    required this.icono,
    required this.onPressed,
    this.activo = false,
  });

  final String tooltip;
  final IconData icono;
  final VoidCallback? onPressed;
  final bool activo;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icono),
      color: activo ? AppColors.primaryDark : Colors.white,
      disabledColor: Colors.white38,
      style: IconButton.styleFrom(
        backgroundColor: activo
            ? AppColors.primaryFixed
            : const Color(0x66000000),
        fixedSize: const Size(44, 44),
      ),
    );
  }
}

/// Las cuatro esquinas del marco de escaneo.
class _EsquinasPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final pintura = Paint()
      ..color = AppColors.primaryFixed
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const largo = 32.0;
    const radio = Radius.circular(14);
    const r = 14.0;
    final w = size.width;
    final h = size.height;

    canvas
      ..drawPath(
        Path()
          ..moveTo(0, largo)
          ..lineTo(0, r)
          ..arcToPoint(const Offset(r, 0), radius: radio)
          ..lineTo(largo, 0),
        pintura,
      )
      ..drawPath(
        Path()
          ..moveTo(w - largo, 0)
          ..lineTo(w - r, 0)
          ..arcToPoint(Offset(w, r), radius: radio)
          ..lineTo(w, largo),
        pintura,
      )
      ..drawPath(
        Path()
          ..moveTo(w, h - largo)
          ..lineTo(w, h - r)
          ..arcToPoint(Offset(w - r, h), radius: radio)
          ..lineTo(w - largo, h),
        pintura,
      )
      ..drawPath(
        Path()
          ..moveTo(largo, h)
          ..lineTo(r, h)
          ..arcToPoint(Offset(0, h - r), radius: radio)
          ..lineTo(0, h - largo),
        pintura,
      );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
