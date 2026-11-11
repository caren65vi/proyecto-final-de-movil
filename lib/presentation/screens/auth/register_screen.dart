import 'package:flutter/material.dart';

import '../../../core/utils/validator_form.dart';

import '../../../domain/entities/facultad.dart';
import '../../../domain/entities/programa.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/usecases/auth_usecases.dart';
import '../../../domain/usecases/facultad_usecases.dart';
import '../../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../widgets/mensaje_error.dart';

enum UserRole { student, teacher }

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    required this.registrarUsuario,
    required this.obtenerFacultades,
    required this.obtenerProgramas,
    required this.asignarPrograma,
  });

  final RegistrarUsuario registrarUsuario;

  // El estudiante elige su facultad y su programa al registrarse
  final ObtenerFacultades obtenerFacultades;
  final ObtenerProgramas obtenerProgramas;
  final AsignarProgramaEstudiante asignarPrograma;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  UserRole _selectedRole = UserRole.student;

  // Facultad y programa (solo para estudiantes)
  late final Stream<List<Facultad>> _facultades = widget.obtenerFacultades();
  Stream<List<Programa>>? _programas;
  List<Facultad> _listaFacultades = const [];
  List<Programa> _listaProgramas = const [];
  String? _facultadId;
  String? _programaId;

  void _elegirFacultad(String? id) {
    setState(() {
      _facultadId = id;
      _programaId = null;
      _listaProgramas = const [];
      _programas = id == null ? null : widget.obtenerProgramas(id);
    });
  }

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;
  bool _loading = false;

  // Tras el primer intento, los errores se actualizan mientras escribe
  AutovalidateMode _autovalidar = AutovalidateMode.disabled;

  // Falta aceptar los términos (se muestra bajo la casilla)
  bool _faltanTerminos = false;

  // Error de Firebase (ej. correo ya registrado), sobre el botón
  String? _errorRegistro;

  void _limpiarErrorRegistro(String _) {
    if (_errorRegistro != null) setState(() => _errorRegistro = null);
  }

  @override
  void initState() {
    super.initState();

    _passwordController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  int get _passwordStrength {
    final password = _passwordController.text;

    if (password.isEmpty) {
      return 0;
    }

    int strength = 0;

    if (password.length >= 8) {
      strength++;
    }

    if (RegExp(r'[A-Za-z]').hasMatch(password)) {
      strength++;
    }

    if (RegExp(r'[0-9]').hasMatch(password)) {
      strength++;
    }

    return strength;
  }

  String get _passwordStrengthLabel {
    switch (_passwordStrength) {
      case 1:
        return 'Baja';
      case 2:
        return 'Media';
      case 3:
        return 'Alta';
      default:
        return 'Sin evaluar';
    }
  }

  Color get _passwordStrengthColor {
    switch (_passwordStrength) {
      case 1:
        return AppColors.secondary;
      case 2:
        return AppColors.tertiary;
      case 3:
        return AppColors.primary;
      default:
        return AppColors.outlineVariant;
    }
  }

  Future<void> _continueRegistration() async {
    setState(() {
      _autovalidar = AutovalidateMode.onUserInteraction;
      _errorRegistro = null;
      _faltanTerminos = !_acceptTerms;
    });
    // Cada campo mal llenado muestra su error debajo
    final formularioValido = _formKey.currentState!.validate();
    if (!formularioValido || !_acceptTerms) {
      return;
    }

    setState(() => _loading = true);
    try {
      // Crea la cuenta en Firebase; la pantalla siguiente envía el código
      final usuario = await widget.registrarUsuario(
        nombre: _nameController.text,
        correo: _emailController.text,
        contrasena: _passwordController.text,
        rol: _selectedRole == UserRole.student ? 'estudiante' : 'docente',
      );

      // La cuenta ya quedó con la sesión abierta: se guarda su programa.
      // Si falla, la cuenta igual sirve y lo puede elegir en su Perfil.
      if (_selectedRole == UserRole.student) {
        final facultad = _listaFacultades
            .where((f) => f.id == _facultadId)
            .firstOrNull;
        final programa = _listaProgramas
            .where((p) => p.id == _programaId)
            .firstOrNull;
        if (facultad != null && programa != null) {
          try {
            await widget.asignarPrograma(
              uid: usuario.uid,
              facultad: facultad,
              programa: programa,
            );
          } catch (_) {
            _showError(
              'Tu cuenta se creó, pero no se guardó el programa. '
              'Elígelo luego en tu Perfil.',
            );
          }
        }
      }
      if (!mounted) return;

      // Reemplaza el registro: la cuenta ya existe y no debe volver al formulario
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.verificarCorreo,
        arguments: _emailController.text.trim(),
      );
    } on AuthError catch (e) {
      if (mounted) setState(() => _errorRegistro = e.mensaje);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _errorRegistro = 'No se pudo crear la cuenta. Intenta de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Dos listas enlazadas: la facultad y luego un programa de esa facultad
  Widget _buildPrograma() {
    return StreamBuilder<List<Facultad>>(
      stream: _facultades,
      builder: (context, snapFacultades) {
        _listaFacultades = snapFacultades.data ?? const [];
        final cargando =
            snapFacultades.data == null && !snapFacultades.hasError;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _FieldLabel(label: 'Facultad'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _facultadId,
              isExpanded: true,
              decoration: InputDecoration(
                hintText: cargando
                    ? 'Cargando facultades…'
                    : (_listaFacultades.isEmpty
                          ? 'Aún no hay facultades'
                          : 'Selecciona tu facultad'),
                prefixIcon: const Icon(Icons.apartment_outlined, size: 20),
              ),
              items: [
                for (final f in _listaFacultades)
                  DropdownMenuItem(value: f.id, child: Text(f.nombre)),
              ],
              onChanged: _loading ? null : _elegirFacultad,
              validator: (v) =>
                  ValidatorForm.validateSelection(v, 'Selecciona tu facultad'),
            ),
            const SizedBox(height: 16),
            const _FieldLabel(label: 'Programa'),
            const SizedBox(height: 6),
            StreamBuilder<List<Programa>>(
              stream: _programas,
              builder: (context, snapProgramas) {
                _listaProgramas = _facultadId == null
                    ? const []
                    : (snapProgramas.data ?? const []);
                final sinProgramas =
                    _facultadId != null &&
                    snapProgramas.data != null &&
                    _listaProgramas.isEmpty;
                return DropdownButtonFormField<String>(
                  // La key reinicia el campo al cambiar de facultad
                  key: ValueKey('programa-$_facultadId'),
                  initialValue: _programaId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    hintText: _facultadId == null
                        ? 'Primero elige la facultad'
                        : (sinProgramas
                              ? 'Esta facultad aún no tiene programas'
                              : 'Selecciona tu programa'),
                    prefixIcon: const Icon(Icons.school_outlined, size: 20),
                  ),
                  items: [
                    for (final p in _listaProgramas)
                      DropdownMenuItem(value: p.id, child: Text(p.nombre)),
                  ],
                  onChanged: _loading || _facultadId == null
                      ? null
                      : (v) => setState(() => _programaId = v),
                  validator: (v) => ValidatorForm.validateSelection(
                    v,
                    'Selecciona tu programa',
                  ),
                );
              },
            ),
          ],
        );
      },
    );
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Form(
            key: _formKey,
            autovalidateMode: _autovalidar,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Barra superior
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Material(
                      color: AppColors.surfaceLow,
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: 'Volver',
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.arrow_back_rounded, size: 22),
                      ),
                    ),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFDAD2),
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
                            'REGISTRO ACADÉMICO',
                            style: TextStyle(
                              color: Color(0xFF3D0600),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Logo + título
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      padding: const EdgeInsets.all(4),
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
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/images/ceiba_logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    const SizedBox(width: 14),

                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Crear cuenta',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Ceiba · Portal Unificado de Gestión Universitaria',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Selector de perfil
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Flexible(
                      child: Text(
                        'Tipo de perfil académico *',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      'Requerido',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                _RoleCard(
                  title: 'Estudiante',
                  icon: Icons.school_rounded,
                  selected: _selectedRole == UserRole.student,
                  onTap: () {
                    setState(() {
                      _selectedRole = UserRole.student;
                    });
                  },
                ),

                const SizedBox(height: 10),

                _RoleCard(
                  title: 'Docente',
                  icon: Icons.co_present_outlined,
                  selected: _selectedRole == UserRole.teacher,
                  onTap: () {
                    setState(() {
                      _selectedRole = UserRole.teacher;
                    });
                  },
                ),

                // Facultad y programa: solo los estudiantes
                if (_selectedRole == UserRole.student) ...[
                  const SizedBox(height: 24),
                  _buildPrograma(),
                ],

                const SizedBox(height: 24),

                // Nombre
                const _FieldLabel(label: 'Nombre completo'),

                const SizedBox(height: 6),

                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  decoration: const InputDecoration(
                    hintText: 'Ej. Mateo Valencia Gómez',
                    prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                  ),
                  validator: (value) => ValidatorForm.validateRequired(
                    value,
                    'Ingresa tu nombre completo',
                  ),
                ),

                const SizedBox(height: 16),

                // Correo
                const _FieldLabel(label: 'Correo institucional'),

                const SizedBox(height: 6),

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  onChanged: _limpiarErrorRegistro,
                  autofillHints: const [AutofillHints.email],
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    hintText: 'usuario@udla.edu.co',
                    prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
                  ),
                  validator: ValidatorForm.validateEmailInstitucional,
                ),

                const SizedBox(height: 6),

                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 15,
                      color: AppColors.tertiary,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Debe ser tu correo oficial universitario @udla.edu.co',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Contraseña
                const _FieldLabel(label: 'Contraseña'),

                const SizedBox(height: 6),

                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: InputDecoration(
                    hintText: '••••••••••••',
                    prefixIcon: const Icon(
                      Icons.lock_outline_rounded,
                      size: 20,
                    ),
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword
                          ? 'Mostrar contraseña'
                          : 'Ocultar contraseña',
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                      ),
                    ),
                  ),
                  validator: ValidatorForm.validateNewPassword,
                ),

                const SizedBox(height: 8),

                // Seguridad contraseña
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Seguridad de contraseña:',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      _passwordStrengthLabel,
                      style: TextStyle(
                        color: _passwordStrengthColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                Row(
                  children: List.generate(3, (index) {
                    final active = index < _passwordStrength;

                    return Expanded(
                      child: Container(
                        height: 6,
                        margin: EdgeInsets.only(right: index < 2 ? 4 : 0),
                        decoration: BoxDecoration(
                          color: active
                              ? _passwordStrengthColor
                              : const Color(0xFFE1E3E1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 6),

                const Text(
                  'Mínimo 8 caracteres, números y letras.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 16),

                // Confirmar contraseña
                const _FieldLabel(label: 'Confirmar contraseña'),

                const SizedBox(height: 6),

                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: InputDecoration(
                    hintText: '••••••••••••',
                    prefixIcon: const Icon(
                      Icons.verified_user_outlined,
                      size: 20,
                    ),
                    suffixIcon: IconButton(
                      tooltip: _obscureConfirmPassword
                          ? 'Mostrar contraseña'
                          : 'Ocultar contraseña',
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                      ),
                    ),
                  ),
                  validator: (value) => ValidatorForm.validateConfirmPassword(
                    value,
                    _passwordController.text,
                  ),
                ),

                const SizedBox(height: 20),

                // Términos
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      setState(() {
                        _acceptTerms = !_acceptTerms;
                        if (_acceptTerms) _faltanTerminos = false;
                      });
                    },
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _acceptTerms,
                          activeColor: AppColors.primary,
                          onChanged: (value) {
                            setState(() {
                              _acceptTerms = value ?? false;
                              if (_acceptTerms) _faltanTerminos = false;
                            });
                          },
                        ),

                        const SizedBox(width: 4),

                        const Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(top: 10),
                            child: Text.rich(
                              TextSpan(
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Acepto el tratamiento de datos personales y el ',
                                  ),
                                  TextSpan(
                                    text: 'reglamento académico institucional',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  TextSpan(text: ' de Ceiba.'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (_faltanTerminos)
                  const ErrorDeCampo(
                    texto:
                        'Debes aceptar el tratamiento de datos y el '
                        'reglamento académico.',
                  ),

                const SizedBox(height: 20),

                // Error de Firebase sobre el botón
                if (_errorRegistro != null) ...[
                  MensajeError(texto: _errorRegistro!),
                  const SizedBox(height: 12),
                ],

                // Continuar
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    // Deshabilitado mientras espera la respuesta de Firebase
                    onPressed: _loading ? null : _continueRegistration,
                    child: _loading
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
                              Text(
                                'Continuar',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 18),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '¿Ya tienes una cuenta?',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Iniciar sesión',
                        style: TextStyle(
                          color: AppColors.secondary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.verified_outlined,
                      color: AppColors.textSecondary,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Sistema de Información Académica · Ceiba',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;

  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 3),
        const Text(
          '*',
          style: TextStyle(
            color: AppColors.secondary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : AppColors.surfaceLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            if (selected)
              Positioned(
                left: 0,
                top: 12,
                bottom: 12,
                child: Container(
                  width: 4,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.horizontal(
                      right: Radius.circular(4),
                    ),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFB5EFDA)
                          : AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      size: 24,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: selected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.w600,
                      ),
                    ),
                  ),

                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary
                          : const Color(0xFFE1E3E1),
                      shape: BoxShape.circle,
                    ),
                    child: selected
                        ? const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: Colors.white,
                          )
                        : null,
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
