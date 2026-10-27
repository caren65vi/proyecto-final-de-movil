import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import 'reset_password_screen.dart';

enum VerifyCodePurpose { registration, passwordRecovery }

class VerifyCodeScreen extends StatefulWidget {
  final String email;
  final VerifyCodePurpose purpose;

  const VerifyCodeScreen({
    super.key,
    required this.email,
    required this.purpose,
  });

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );

  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  Timer? _timer;

  int _secondsRemaining = 299;

  bool get _canResend => _secondsRemaining <= 0;

  String get _formattedTime {
    final minutes = _secondsRemaining ~/ 60;
    final seconds = _secondsRemaining % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  bool get _isPasswordRecovery {
    return widget.purpose == VerifyCodePurpose.passwordRecovery;
  }

  @override
  void initState() {
    super.initState();

    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();

    for (final controller in _controllers) {
      controller.dispose();
    }

    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }

    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();

    setState(() {
      _secondsRemaining = 299;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 0) {
        timer.cancel();
        return;
      }

      setState(() {
        _secondsRemaining--;
      });
    });
  }

  void _onCodeChanged(String value, int index) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }

    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  void _clearCode() {
    for (final controller in _controllers) {
      controller.clear();
    }

    _focusNodes.first.requestFocus();
  }

  void _resendCode() {
    if (!_canResend) {
      return;
    }

    // Por ahora NO se envía ningún código real.
    _clearCode();
    _startTimer();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Se simuló el envío de un nuevo código.')),
    );
  }

  void _confirmCode() {
    // POR AHORA:
    // No validamos si las 6 casillas están completas.
    // No consultamos Firebase.
    // No comprobamos ningún código.

    if (_isPasswordRecovery) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResetPasswordScreen(email: widget.email),
        ),
      );

      return;
    }

    // Flujo de creación de cuenta.
    //
    // Temporalmente volvemos al Login,
    // que actualmente es la primera pantalla de la aplicación.
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,

        leading: IconButton(
          tooltip: 'Volver',
          onPressed: () {
            Navigator.pop(context);
          },
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

        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'Código de verificación',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Badge
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                        ),
                      ),

                      const SizedBox(width: 6),

                      const Text(
                        'VERIFICACIÓN DE SEGURIDAD',
                        style: TextStyle(
                          color: AppColors.secondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Logo / seguridad
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Image.asset(
                        'assets/images/ceiba_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),

                    Positioned(
                      right: -7,
                      bottom: -7,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: AppColors.tertiary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_open_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                'Verifica tu correo',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Hemos enviado un código de seguridad de 6 dígitos '
                'a tu buzón institucional:',
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
                        Icons.school_outlined,
                        color: AppColors.primary,
                        size: 18,
                      ),

                      const SizedBox(width: 8),

                      Flexible(
                        child: Text(
                          widget.email.isEmpty
                              ? 'Correo institucional'
                              : widget.email,
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

              // Tarjeta OTP
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.06),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Código de confirmación',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        Row(
                          children: [
                            const Icon(
                              Icons.timer_outlined,
                              color: AppColors.primary,
                              size: 15,
                            ),

                            const SizedBox(width: 4),

                            Text(
                              'Expira en $_formattedTime',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 6 casillas
                    Row(
                      children: List.generate(6, (index) {
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: index == 5 ? 0 : 6),
                            child: SizedBox(
                              height: 56,
                              child: TextField(
                                controller: _controllers[index],
                                focusNode: _focusNodes[index],
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,

                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(1),
                                ],

                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),

                                decoration: InputDecoration(
                                  contentPadding: EdgeInsets.zero,

                                  filled: true,

                                  fillColor: AppColors.surfaceLow,

                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),

                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),

                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: AppColors.primary,
                                      width: 2,
                                    ),
                                  ),
                                ),

                                onChanged: (value) {
                                  _onCodeChanged(value, index);
                                },
                              ),
                            ),
                          ),
                        );
                      }),
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

              const SizedBox(height: 22),

              const Text(
                '¿No recibiste el código?',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),

              const SizedBox(height: 6),

              Center(
                child: TextButton.icon(
                  onPressed: _canResend ? _resendCode : null,

                  icon: const Icon(Icons.replay_rounded, size: 18),

                  label: Text(
                    _canResend
                        ? 'Solicitar nuevo código'
                        : 'Solicitar nuevo código ($_formattedTime)',
                  ),
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _confirmCode,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Confirmar y continuar'),

                      SizedBox(width: 8),

                      Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              SizedBox(
                height: 44,
                child: FilledButton.tonal(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.arrow_back_rounded, size: 18),

                      const SizedBox(width: 8),

                      Text(
                        _isPasswordRecovery
                            ? 'Volver a recuperación'
                            : 'Volver al registro',
                      ),
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
    );
  }
}
