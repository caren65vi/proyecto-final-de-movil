import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/entities/usuario.dart';
import '../../../domain/usecases/auth_usecases.dart';
import '../../../routes/app_routes.dart';
import '../../theme/app_colors.dart';

/// Pantalla de carga animada: se muestra al abrir la app mientras se revisa
/// si ya había una sesión abierta. Luego va al inicio según el rol o al login.
class CargaScreen extends StatefulWidget {
  const CargaScreen({super.key, required this.restaurarSesion});

  final RestaurarSesion restaurarSesion;

  @override
  State<CargaScreen> createState() => _CargaScreenState();
}

class _CargaScreenState extends State<CargaScreen>
    with TickerProviderStateMixin {
  // Tiempo mínimo en pantalla para que la animación alcance a verse
  static const _duracionMinima = Duration(milliseconds: 2200);

  late final AnimationController _giroExterno = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 22),
  )..repeat();
  late final AnimationController _giroInterno = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();
  late final AnimationController _ondas = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat();
  late final AnimationController _pulso = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);
  late final AnimationController _barra = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  String _estado = 'Sincronizando espacio académico...';

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  @override
  void dispose() {
    _giroExterno.dispose();
    _giroInterno.dispose();
    _ondas.dispose();
    _pulso.dispose();
    _barra.dispose();
    super.dispose();
  }

  Future<void> _iniciar() async {
    // Se cambia el texto a mitad de la espera
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _estado = 'Verificando tu sesión...');
    });

    final resultados = await Future.wait([
      // Si falla (sin internet, etc.) simplemente se va al login
      widget.restaurarSesion().then<Object?>((u) => u, onError: (_) => null),
      Future<Object?>.delayed(_duracionMinima),
    ]);
    if (!mounted) return;

    final usuario = resultados.first;
    if (usuario is Usuario) {
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.homeDe(usuario),
        arguments: usuario,
      );
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Brillos de fondo
          Positioned(
            top: -96,
            left: -96,
            child: _Brillo(color: AppColors.primaryFixed, tamano: 320),
          ),
          Positioned(
            bottom: -80,
            right: -80,
            child: _Brillo(color: AppColors.tertiaryFixed, tamano: 288),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _emblema(),
                            const SizedBox(height: 24),
                            const Text(
                              'Ceiba',
                              style: TextStyle(
                                color: AppColors.primaryDark,
                                fontSize: 26,
                                height: 34 / 26,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.26,
                              ),
                            ),
                            const SizedBox(height: 4),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Text(
                                _estado,
                                key: ValueKey(_estado),
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                  height: 20 / 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _barraProgreso(),
                            const SizedBox(height: 16),
                            _insigniaConexion(),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.school, size: 16, color: AppColors.tertiary),
                      SizedBox(width: 6),
                      Text(
                        'Universidad de la Amazonia',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.24,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Logo con ondas, halo y dos anillos orbitando en sentidos opuestos
  Widget _emblema() {
    return SizedBox(
      width: 256,
      height: 256,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _Onda(
            animacion: _ondas,
            tamano: 224,
            color: AppColors.onPrimaryContainer,
          ),
          _Onda(
            animacion: _ondas,
            tamano: 176,
            color: AppColors.tertiaryFixed,
            desfase: 0.25,
          ),

          // Anillo exterior punteado (giro horario)
          RotationTransition(
            turns: _giroExterno,
            child: SizedBox(
              width: 240,
              height: 240,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _CirculoPunteado(
                        color: AppColors.outlineVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  const Positioned(
                    top: -8,
                    left: 112,
                    child: _Gema(
                      tamano: 16,
                      color: AppColors.tertiary,
                      centro: Colors.white,
                    ),
                  ),
                  const Positioned(
                    bottom: -10,
                    left: 110,
                    child: _Gema(
                      tamano: 20,
                      color: AppColors.secondary,
                      centro: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Anillo interior (giro antihorario)
          RotationTransition(
            turns: ReverseAnimation(_giroInterno),
            child: Container(
              width: 192,
              height: 192,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primaryDark.withValues(alpha: 0.2),
                ),
              ),
              child: const Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: -8,
                    top: 88,
                    child: _Gema(
                      tamano: 14,
                      color: AppColors.primary,
                      centro: AppColors.primaryFixed,
                    ),
                  ),
                  Positioned(
                    right: -7,
                    top: 89,
                    child: _Gema(
                      tamano: 12,
                      color: AppColors.onTertiaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Halo que late detrás del logo
          // (se anima el color de la sombra y no la opacidad del widget:
          // Impeller no admite opacidad heredada sobre sombras difuminadas)
          AnimatedBuilder(
            animation: _pulso,
            builder: (context, _) => Container(
              width: 144,
              height: 144,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(
                      alpha: 0.07 + 0.11 * _pulso.value,
                    ),
                    blurRadius: 32,
                    spreadRadius: 8,
                  ),
                ],
              ),
            ),
          ),

          // Logo que "respira"
          ScaleTransition(
            scale: Tween(
              begin: 0.97,
              end: 1.03,
            ).animate(CurvedAnimation(parent: _pulso, curve: Curves.easeInOut)),
            child: Container(
              width: 128,
              height: 128,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/images/ceiba_logo.png',
                  width: 96,
                  height: 96,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Barra indeterminada: un tramo que recorre la pista de izquierda a derecha
  Widget _barraProgreso() {
    const ancho = 176.0;
    const tramo = ancho * 0.4;
    return Container(
      width: ancho,
      height: 6,
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedBuilder(
        animation: _barra,
        builder: (context, child) {
          final t = Curves.easeInOutCubic.transform(_barra.value);
          return Stack(
            children: [
              Positioned(
                left: -tramo + (ancho + tramo) * t,
                top: 0,
                bottom: 0,
                width: tramo,
                child: child!,
              ),
            ],
          );
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.primaryDark,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }

  Widget _insigniaConexion() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 8,
            height: 8,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _Onda(
                  animacion: _barra,
                  tamano: 8,
                  color: AppColors.primary,
                  escalaMaxima: 2,
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryDark,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Conexión segura con el campus',
            style: TextStyle(
              color: AppColors.primaryDark,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.33,
            ),
          ),
        ],
      ),
    );
  }
}

/// Círculo que crece y se desvanece en bucle (efecto "ping").
class _Onda extends StatelessWidget {
  const _Onda({
    required this.animacion,
    required this.tamano,
    required this.color,
    this.desfase = 0,
    this.escalaMaxima = 1.25,
  });

  final Animation<double> animacion;
  final double tamano;
  final Color color;
  final double desfase;
  final double escalaMaxima;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animacion,
      builder: (context, _) {
        final t = (animacion.value + desfase) % 1;
        return Transform.scale(
          scale: 1 + (escalaMaxima - 1) * t,
          child: Container(
            width: tamano,
            height: tamano,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.35 * (1 - t)),
            ),
          ),
        );
      },
    );
  }
}

/// Punto de color con un centro más claro, usado en los anillos.
class _Gema extends StatelessWidget {
  const _Gema({required this.tamano, required this.color, this.centro});

  final double tamano;
  final Color color;
  final Color? centro;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: centro == null
          ? null
          : Container(
              width: tamano * 0.4,
              height: tamano * 0.4,
              decoration: BoxDecoration(color: centro, shape: BoxShape.circle),
            ),
    );
  }
}

/// Mancha de color difuminada para el fondo.
class _Brillo extends StatelessWidget {
  const _Brillo({required this.color, required this.tamano});

  final Color color;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: tamano,
        height: tamano,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

/// Borde circular punteado.
class _CirculoPunteado extends CustomPainter {
  const _CirculoPunteado({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const grosor = 2.0;
    const segmentos = 48;
    final pincel = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromLTWH(
      grosor / 2,
      grosor / 2,
      size.width - grosor,
      size.height - grosor,
    );
    const paso = 2 * math.pi / segmentos;
    for (var i = 0; i < segmentos; i++) {
      canvas.drawArc(rect, i * paso, paso * 0.5, false, pincel);
    }
  }

  @override
  bool shouldRepaint(_CirculoPunteado oldDelegate) =>
      oldDelegate.color != color;
}
