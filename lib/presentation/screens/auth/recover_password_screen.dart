import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/usecases/auth_usecases.dart';
import '../../theme/app_colors.dart';

class RecoverPasswordScreen extends StatefulWidget {
  const RecoverPasswordScreen({
    super.key,
    required this.recuperarContrasena,
    this.correoInicial = '',
  });

  // Caso de uso que pide a Firebase enviar el enlace de recuperación
  final RecuperarContrasena recuperarContrasena;

  // Correo que el usuario ya había escrito en el login
  final String correoInicial;

  @override
  State<RecoverPasswordScreen> createState() => _RecoverPasswordScreenState();
}

class _RecoverPasswordScreenState extends State<RecoverPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;

  bool _loading = false;

  // Correo al que se envió el enlace; null mientras se muestra el formulario
  String? _correoEnviado;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.correoInicial);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _loading = true);
    try {
      await widget.recuperarContrasena(_emailController.text);
      if (!mounted) return;
      setState(() => _correoEnviado = _emailController.text.trim());
    } on AuthError catch (e) {
      _showError(e.mensaje);
    } catch (_) {
      _showError('Ocurrió un error inesperado. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Vuelve al formulario para escribir otro correo
  void _probarOtroCorreo() {
    setState(() {
      _correoEnviado = null;
      _emailController.clear();
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background.withValues(alpha: 0.8),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.04),
        titleSpacing: 0,
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.textPrimary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Ceiba',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Brillos decorativos de fondo
          const _AmbientGlow(),

          SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 448),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Seguridad y acceso
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceHigh,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColors.secondary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'SEGURIDAD Y ACCESO',
                                style: TextStyle(
                                  color: AppColors.primaryDark,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Logo
                      Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryDark.withValues(
                                  alpha: 0.08,
                                ),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              'assets/images/ceiba_logo.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      const Text(
                        'Recuperar contraseña',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 26,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),

                      const SizedBox(height: 4),

                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'Ingresa tu correo institucional registrado para recibir un enlace de restablecimiento seguro.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Tarjeta: formulario o confirmación
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _correoEnviado == null
                              ? _buildForm()
                              : _SuccessPanel(
                                  correo: _correoEnviado!,
                                  onProbarOtro: _probarOtroCorreo,
                                ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Volver al login
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            '¿Recordaste tu contraseña?',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Iniciar sesión',
                                  style: TextStyle(
                                    color: AppColors.primaryDark,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                    decorationColor: AppColors.primaryDark,
                                  ),
                                ),
                                SizedBox(width: 2),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 14,
                                  color: AppColors.primaryDark,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Correo
          Row(
            children: [
              const Text(
                'Correo institucional',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 3),
              const Text(
                '*',
                style: TextStyle(
                  color: AppColors.secondary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              const Text(
                'Acceso único',
                style: TextStyle(color: AppColors.outline, fontSize: 11),
              ),
            ],
          ),

          const SizedBox(height: 6),

          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.send,
            onFieldSubmitted: (_) => _loading ? null : _enviar(),
            decoration: const InputDecoration(
              hintText: 'usuario@udla.edu.co',
              prefixIcon: Icon(Icons.school_outlined, size: 20),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Ingresa tu correo institucional';
              }

              if (!value.contains('@')) {
                return 'Ingresa un correo válido';
              }

              return null;
            },
          ),

          const SizedBox(height: 6),

          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 15,
                color: AppColors.primaryDark,
              ),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Te enviaremos un correo con instrucciones para crear una nueva clave.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          SizedBox(
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                shape: const StadiumBorder(),
                elevation: 2,
              ),
              // Deshabilitado mientras espera la respuesta de Firebase
              onPressed: _loading ? null : _enviar,
              child: _loading
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
                        Text('Enviar enlace de recuperación'),
                        SizedBox(width: 8),
                        Icon(Icons.send_rounded, size: 18),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Confirmación que reemplaza al formulario cuando Firebase envía el correo.
class _SuccessPanel extends StatelessWidget {
  final String correo;
  final VoidCallback onProbarOtro;

  const _SuccessPanel({required this.correo, required this.onProbarOtro});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: AppColors.primaryFixed,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read_rounded,
            size: 28,
            color: AppColors.primary,
          ),
        ),

        const SizedBox(height: 8),

        const Text(
          '¡Enlace enviado!',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 4),

        // Firebase no revela si el correo existe, por eso el "si está registrado"
        Text.rich(
          TextSpan(
            text: 'Si ',
            children: [
              TextSpan(
                text: correo,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const TextSpan(
                text: ' está registrado, recibirás un correo con el enlace seguro. Revisa también la carpeta de spam.',
              ),
            ],
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            height: 1.35,
          ),
        ),

        const SizedBox(height: 16),

        TextButton(
          onPressed: onProbarOtro,
          style: TextButton.styleFrom(
            backgroundColor: AppColors.surfaceContainer,
            foregroundColor: AppColors.primary,
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: const Text(
            'Probar con otro correo',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// Dos círculos difuminados detrás del contenido.
class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
          child: Stack(
            children: [
              Positioned(
                top: -48,
                right: -48,
                child: _circle(360, AppColors.primaryFixed, 0.3),
              ),
              Positioned(
                bottom: 40,
                left: -48,
                child: _circle(280, AppColors.secondaryFixed, 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circle(double size, Color color, double alpha) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: alpha),
        shape: BoxShape.circle,
      ),
    );
  }
}
