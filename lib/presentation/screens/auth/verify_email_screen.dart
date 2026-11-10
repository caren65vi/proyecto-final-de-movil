import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/usecases/auth_usecases.dart';
import '../../theme/app_colors.dart';

/// Pantalla que se muestra después de crear la cuenta (o al intentar entrar
/// sin haber verificado): envía un código de 6 dígitos al correo y lo pide.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({
    super.key,
    required this.email,
    required this.enviarCodigo,
    required this.verificarCodigo,
    required this.cerrarSesion,
  });

  final String email;
  final EnviarCodigoVerificacion enviarCodigo;
  final VerificarCodigo verificarCodigo;
  final CerrarSesion cerrarSesion;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  static const _largoCodigo = 6;
  // Deben coincidir con la Cloud Function
  static const _vigencia = Duration(minutes: 10);
  static const _esperaReenvio = Duration(seconds: 60);

  final _codigoController = TextEditingController();
  final _codigoFocus = FocusNode();

  Timer? _reloj;
  DateTime? _expiraEn;
  DateTime? _reenvioEn;

  bool _enviando = false;
  bool _verificando = false;

  Duration _restante(DateTime? hasta) {
    if (hasta == null) return Duration.zero;
    final d = hasta.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  bool get _puedeReenviar =>
      !_enviando && _restante(_reenvioEn) == Duration.zero;

  bool get _vencido =>
      _expiraEn != null && _restante(_expiraEn) == Duration.zero;

  @override
  void initState() {
    super.initState();
    // Un segundo basta para las dos cuentas regresivas
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _enviarCodigo();
  }

  @override
  void dispose() {
    _reloj?.cancel();
    _codigoController.dispose();
    _codigoFocus.dispose();
    super.dispose();
  }

  Future<void> _enviarCodigo() async {
    setState(() => _enviando = true);
    try {
      final espera = await widget.enviarCodigo();
      if (!mounted) return;

      final ahora = DateTime.now();
      // Si la espera es menor que la completa, el código anterior sigue
      // vigente: se envió hace (60 - espera) segundos
      final enviadoHace = _esperaReenvio - Duration(seconds: espera);
      setState(() {
        _reenvioEn = ahora.add(Duration(seconds: espera));
        _expiraEn = ahora.add(_vigencia - enviadoHace);
      });
      if (espera >= _esperaReenvio.inSeconds) {
        _codigoController.clear();
        _mostrarMensaje('Te enviamos un código a ${widget.email}.');
      }
    } on AuthError catch (e) {
      _mostrarMensaje(e.mensaje, error: true);
    } catch (_) {
      _mostrarMensaje(
        'No se pudo enviar el código. Intenta de nuevo.',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _confirmar() async {
    if (_verificando) return;
    setState(() => _verificando = true);
    try {
      await widget.verificarCodigo(_codigoController.text);
      if (!mounted) return;

      // Se cierra la sesión que abrió el registro para que entre desde el login
      final messenger = ScaffoldMessenger.of(context);
      await widget.cerrarSesion();
      if (!mounted) return;

      Navigator.popUntil(context, (route) => route.isFirst);
      // Reemplaza el aviso "Te enviamos un código..." si sigue visible
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Correo verificado. Ya puedes iniciar sesión.'),
          ),
        );
    } on AuthError catch (e) {
      _codigoController.clear();
      _codigoFocus.requestFocus();
      _mostrarMensaje(e.mensaje, error: true);
    } catch (_) {
      _mostrarMensaje(
        'Ocurrió un error inesperado. Intenta de nuevo.',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _verificando = false);
    }
  }

  // Sale al login sin dejar la sesión de la cuenta sin verificar abierta
  Future<void> _volverAlLogin() async {
    await widget.cerrarSesion();
    if (!mounted) return;
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  void _mostrarMensaje(String mensaje, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: error ? AppColors.error : null,
        ),
      );
  }

  static String _mmss(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // El botón atrás del sistema también cierra la sesión
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _volverAlLogin();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
            tooltip: 'Volver',
            onPressed: _volverAlLogin,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Row(
            children: [
              Image.asset(
                'assets/images/ceiba_logo.png',
                width: 32,
                height: 32,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 8),
              const Text(
                'Ceiba',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: _EtiquetaSeguridad(),
                ),
                const SizedBox(height: 20),
                const Center(child: _LogoConCandado()),
                const SizedBox(height: 16),
                const Text(
                  'Verifica tu correo',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Hemos enviado un código de seguridad de 6 dígitos a tu '
                  'correo institucional:',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                Center(child: _ChipCorreo(correo: widget.email)),
                const SizedBox(height: 24),
                _tarjetaCodigo(),
                const SizedBox(height: 24),
                const Text(
                  '¿No recibiste el código?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Center(child: _botonReenviar()),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _verificando ? null : _confirmar,
                    child: _verificando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Confirmar y continuar',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.surfaceContainer,
                      foregroundColor: AppColors.primaryDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _volverAlLogin,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.arrow_back_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Volver al inicio de sesión'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Sistema de Información Académica · Ceiba',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tarjetaCodigo() {
    final Widget vencimiento;
    if (_expiraEn == null) {
      vencimiento = const SizedBox.shrink();
    } else if (_vencido) {
      vencimiento = const Text(
        'Código vencido',
        style: TextStyle(
          color: AppColors.error,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      );
    } else {
      vencimiento = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 16, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            'Expira en ${_mmss(_restante(_expiraEn))}',
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Código de confirmación',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
              vencimiento,
            ],
          ),
          const SizedBox(height: 14),
          _CasillasCodigo(
            controller: _codigoController,
            focusNode: _codigoFocus,
            largo: _largoCodigo,
            // Al escribir el último dígito se confirma solo
            onCompleto: _confirmar,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_rounded, color: AppColors.tertiary, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text:
                          'Si no encuentras el mensaje en tu bandeja de '
                          'entrada, revisa la carpeta de ',
                      children: [
                        TextSpan(
                          text: 'Correo no deseado o Spam',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(text: ' de tu cuenta institucional.'),
                      ],
                    ),
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.4,
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

  Widget _botonReenviar() {
    final espera = _restante(_reenvioEn);
    final String texto;
    if (_enviando) {
      texto = 'Enviando código...';
    } else if (espera > Duration.zero) {
      texto = 'Solicitar nuevo código (${espera.inSeconds} s)';
    } else {
      texto = 'Solicitar nuevo código';
    }
    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.secondary,
        backgroundColor: AppColors.secondaryFixed.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: _puedeReenviar ? _enviarCodigo : null,
      icon: const Icon(Icons.replay_rounded, size: 18),
      label: Text(texto, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

/// Seis casillas para el código. Debajo hay un único campo de texto
/// invisible que recibe el teclado (y el autocompletado del código).
class _CasillasCodigo extends StatelessWidget {
  const _CasillasCodigo({
    required this.controller,
    required this.focusNode,
    required this.largo,
    required this.onCompleto,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int largo;
  final VoidCallback onCompleto;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Stack(
        children: [
          ListenableBuilder(
            listenable: Listenable.merge([controller, focusNode]),
            builder: (context, _) {
              final texto = controller.text;
              return Row(
                children: [
                  for (var i = 0; i < largo; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _Casilla(
                        digito: i < texto.length ? texto[i] : null,
                        activa:
                            focusNode.hasFocus &&
                            (i == texto.length ||
                                (texto.length == largo && i == largo - 1)),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          // Campo real, transparente, encima de las casillas
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(largo),
                ],
                showCursor: false,
                enableInteractiveSelection: false,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                ),
                onChanged: (valor) {
                  if (valor.length == largo) onCompleto();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Casilla extends StatelessWidget {
  const _Casilla({required this.digito, required this.activa});

  final String? digito;
  final bool activa;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: activa ? Colors.white : AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: activa ? AppColors.primaryDark : Colors.transparent,
          width: 2,
        ),
      ),
      child: digito != null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  digito!,
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Container(
                  width: 14,
                  height: 2,
                  color: AppColors.primary.withValues(alpha: 0.5),
                ),
              ],
            )
          : activa
          ? Container(width: 2, height: 24, color: AppColors.primaryDark)
          : const Text(
              '•',
              style: TextStyle(color: AppColors.outlineVariant, fontSize: 20),
            ),
    );
  }
}

class _EtiquetaSeguridad extends StatelessWidget {
  const _EtiquetaSeguridad();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.secondaryFixed,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 3, backgroundColor: AppColors.secondary),
          SizedBox(width: 6),
          Text(
            'VERIFICACIÓN DE SEGURIDAD',
            style: TextStyle(
              color: AppColors.attendanceWarningText,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoConCandado extends StatelessWidget {
  const _LogoConCandado();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 80,
          height: 80,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/images/ceiba_logo.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        Positioned(
          right: -6,
          bottom: -6,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.tertiary,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.background, width: 2),
            ),
            child: const Icon(
              Icons.lock_rounded,
              size: 14,
              color: AppColors.onTertiaryContainer,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChipCorreo extends StatelessWidget {
  const _ChipCorreo({required this.correo});

  final String correo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.school_outlined, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              correo,
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
    );
  }
}
