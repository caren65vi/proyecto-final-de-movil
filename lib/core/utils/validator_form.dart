/// Validaciones de los formularios (login, registro, recuperar contraseña).
///
/// Cada método se usa directo en `validator:` de un `TextFormField`:
/// devuelve el mensaje de error o `null` si el valor es válido.
class ValidatorForm {
  ValidatorForm._();

  /// Dominio de los correos institucionales de la universidad.
  static const dominioInstitucional = '@udla.edu.co';

  /// Mínimo de caracteres de una contraseña.
  static const largoMinimoContrasena = 8;

  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  /// Campo obligatorio cualquiera (ej. nombre completo).
  static String? validateRequired(String? value, String mensaje) {
    if (value == null || value.trim().isEmpty) return mensaje;
    return null;
  }

  /// Campo obligatorio con largo máximo (ej. nombre de un curso).
  static String? validateText(
    String? value, {
    required String mensaje,
    int? maximo,
  }) {
    final error = validateRequired(value, mensaje);
    if (error != null) return error;
    if (maximo != null && value!.trim().length > maximo) {
      return 'Máximo $maximo caracteres';
    }
    return null;
  }

  /// Opción obligatoria de una lista desplegable.
  static String? validateSelection<T>(T? value, String mensaje) =>
      value == null ? mensaje : null;

  /// Código de verificación de [largo] dígitos.
  static String? validateCodigo(String? value, {int largo = 6}) {
    final codigo = value?.trim() ?? '';
    if (codigo.isEmpty) return 'Ingresa el código';
    if (!RegExp('^\\d{$largo}\$').hasMatch(codigo)) {
      return 'El código tiene $largo dígitos';
    }
    return null;
  }

  /// Código de estudiante opcional: si lo escribe, letras, números o guiones.
  static String? validateCodigoEstudiante(String? value) {
    final codigo = value?.trim() ?? '';
    if (codigo.isEmpty) return null;
    if (!RegExp(r'^[A-Za-z0-9-]{3,20}$').hasMatch(codigo)) {
      return 'Usa solo letras, números o guiones (3 a 20)';
    }
    return null;
  }

  /// Correo con formato válido (usuario@dominio.ext).
  static String? validateEmail(String? value) {
    final correo = value?.trim() ?? '';
    if (correo.isEmpty) return 'Ingresa tu correo institucional';
    if (!_emailRegex.hasMatch(correo)) return 'Ingresa un correo válido';
    return null;
  }

  /// Correo válido y además del dominio @udla.edu.co (para registrarse).
  static String? validateEmailInstitucional(String? value) {
    final error = validateEmail(value);
    if (error != null) return error;
    if (!value!.trim().toLowerCase().endsWith(dominioInstitucional)) {
      return 'Utiliza tu correo institucional $dominioInstitucional';
    }
    return null;
  }

  /// Contraseña al iniciar sesión: obligatoria y de al menos 8 caracteres.
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Ingresa tu contraseña';
    if (value.length < largoMinimoContrasena) {
      return 'La contraseña debe tener al menos '
          '$largoMinimoContrasena caracteres';
    }
    return null;
  }

  /// Contraseña nueva (registro): además debe tener letras y números.
  static String? validateNewPassword(String? value) {
    if (value == null || value.isEmpty) return 'Ingresa una contraseña';
    final error = validatePassword(value);
    if (error != null) return error;
    if (!RegExp(r'[A-Za-z]').hasMatch(value)) {
      return 'La contraseña debe contener letras';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'La contraseña debe contener números';
    }
    return null;
  }

  /// Confirmación: debe ser igual a la contraseña escrita.
  static String? validateConfirmPassword(String? value, String contrasena) {
    if (value == null || value.isEmpty) return 'Confirma tu contraseña';
    if (value != contrasena) return 'Las contraseñas no coinciden';
    return null;
  }
}
