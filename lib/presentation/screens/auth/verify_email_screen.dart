import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/usecases/auth_usecases.dart';
import '../../theme/app_colors.dart';

/// Pantalla que se muestra después de crear la cuenta (o al intentar entrar
/// sin haber verificado): pide abrir el enlace que Firebase envió al correo.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({
    super.key,
    required this.email,
    required this.enviarCorreoVerificacion,
    required this.comprobarCorreoVerificado,
    required this.cerrarSesion,
  });

  final String email;
  final EnviarCorreoVerificacion enviarCorreoVerificacion;
  final ComprobarCorreoVerificado comprobarCorreoVerificado;
  final CerrarSesion cerrarSesion;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  // Firebase limita los reenvíos, así que se espera un minuto entre cada uno
  static const _esperaReenvio = 60;

  Timer? _timer;
  int _segundosRestantes = _esperaReenvio;

  bool _comprobando = false;
  bool _reenviando = false;

  bool get _puedeReenviar => _segundosRestantes <= 0 && !_reenviando;

  @override
  void initState() {
    super.initState();
    _iniciarEspera();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _iniciarEspera() {
    _timer?.cancel();
    setState(() => _segundosRestantes = _esperaReenvio);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_segundosRestantes <= 0) {
        timer.cancel();
        return;
      }
      setState(() => _segundosRestantes--);
    });
  }

  Future<void> _comprobar() async {
    setState(() => _comprobando = true);
    try {
      final verificado = await widget.comprobarCorreoVerificado();
      if (!mounted) return;

      if (!verificado) {
        _showMessage(
          'Aún no has abierto el enlace. Revisa tu correo e inténtalo de nuevo.',
          error: true,
        );
        return;
      }

      // Se cierra la sesión que abrió el registro para que entre desde el login
      final messenger = ScaffoldMessenger.of(context);
      await widget.cerrarSesion();
      if (!mounted) return;

      Navigator.popUntil(context, (route) => route.isFirst);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Correo verificado. Ya puedes iniciar sesión.'),
        ),
      );
    } on AuthError catch (e) {
      _showMessage(e.mensaje, error: true);
    } catch (_) {
      _showMessage('Ocurrió un error inesperado. Intenta de nuevo.', error: true);
    } finally {
      if (mounted) setState(() => _comprobando = false);
    }
  }

  Future<void> _reenviar() async {
    setState(() => _reenviando = true);
    try {
      await widget.enviarCorreoVerificacion();
      if (!mounted) return;

      _iniciarEspera();
      _showMessage('Te enviamos un nuevo enlace a ${widget.email}.');
    } on AuthError catch (e) {
      _showMessage(e.mensaje, error: true);
    } catch (_) {
      _showMessage('No se pudo reenviar el correo. Intenta de nuevo.', error: true);
    } finally {
      if (mounted) setState(() => _reenviando = false);
    }
  }

  // Sale al login sin dejar la sesión de la cuenta sin verificar abierta
  Future<void> _volverAlLogin() async {
    await widget.cerrarSesion();
    if (!mounted) return;
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : null,
      ),
    );
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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Ícono de correo
                Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.mark_email_unread_rounded,
                      color: AppColors.primary,
                      size: 44,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'Revisa tu correo',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Te enviamos un enlace de verificación a:',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),

                const SizedBox(height: 12),

                // Correo
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.alternate_email_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            widget.email,
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
                  ),
                ),

                const SizedBox(height: 28),

                // Pasos
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _Paso(
                        numero: 1,
                        texto: 'Abre el correo de Ceiba en tu bandeja de entrada.',
                      ),
                      const SizedBox(height: 12),
                      const _Paso(
                        numero: 2,
                        texto: 'Pulsa el enlace para verificar tu cuenta.',
                      ),
                      const SizedBox(height: 12),
                      const _Paso(
                        numero: 3,
                        texto: 'Vuelve aquí y pulsa "Ya verifiqué mi correo".',
                      ),
                      const SizedBox(height: 16),

                      // Ayuda
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_rounded,
                              color: AppColors.tertiary,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Si no encuentras el mensaje en tu '
                                'bandeja de entrada, revisa la carpeta '
                                'de Correo no deseado o Spam.',
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
                ),

                const SizedBox(height: 24),

                SizedBox(
                  height: 48,
                  child: FilledButton(
                    // Deshabilitado mientras espera la respuesta de Firebase
                    onPressed: _comprobando ? null : _comprobar,
                    child: _comprobando
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
                              Text('Ya verifiqué mi correo'),
                              SizedBox(width: 8),
                              Icon(Icons.verified_rounded, size: 20),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                const Text(
                  '¿No te llegó el correo?',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),

                const SizedBox(height: 6),

                Center(
                  child: TextButton.icon(
                    onPressed: _puedeReenviar ? _reenviar : null,
                    icon: const Icon(Icons.replay_rounded, size: 18),
                    label: Text(
                      _segundosRestantes > 0
                          ? 'Reenviar correo (${_segundosRestantes}s)'
                          : 'Reenviar correo',
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                SizedBox(
                  height: 44,
                  child: FilledButton.tonal(
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
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Paso extends StatelessWidget {
  final int numero;
  final String texto;

  const _Paso({required this.numero, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$numero',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
