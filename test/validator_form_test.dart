import 'package:ceiba/core/utils/validator_form.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ValidatorForm.validateEmail', () {
    test('vacío o nulo pide el correo', () {
      expect(ValidatorForm.validateEmail(null), isNotNull);
      expect(ValidatorForm.validateEmail('   '), isNotNull);
    });
    test('rechaza formatos inválidos', () {
      for (final c in ['ana', 'ana@', 'ana@udla', '@udla.edu.co', 'a b@x.co']) {
        expect(ValidatorForm.validateEmail(c), 'Ingresa un correo válido');
      }
    });
    test('acepta un correo válido con espacios alrededor', () {
      expect(ValidatorForm.validateEmail(' ana.perez@udla.edu.co '), isNull);
    });
  });

  test('validateEmailInstitucional exige @udla.edu.co', () {
    expect(
      ValidatorForm.validateEmailInstitucional('ana@gmail.com'),
      contains('@udla.edu.co'),
    );
    expect(ValidatorForm.validateEmailInstitucional('Ana@UDLA.edu.co'), isNull);
  });

  test('validatePassword exige mínimo 8 caracteres', () {
    expect(ValidatorForm.validatePassword(''), 'Ingresa tu contraseña');
    expect(ValidatorForm.validatePassword('1234567'), isNotNull);
    expect(ValidatorForm.validatePassword('12345678'), isNull);
  });

  test('validateNewPassword exige letras y números', () {
    expect(
      ValidatorForm.validateNewPassword('abcdefgh'),
      'La contraseña debe contener números',
    );
    expect(
      ValidatorForm.validateNewPassword('12345678'),
      'La contraseña debe contener letras',
    );
    expect(ValidatorForm.validateNewPassword('clave1234'), isNull);
  });

  test('validateConfirmPassword compara con la contraseña', () {
    expect(ValidatorForm.validateConfirmPassword('', 'clave1234'), isNotNull);
    expect(
      ValidatorForm.validateConfirmPassword('otra1234', 'clave1234'),
      'Las contraseñas no coinciden',
    );
    expect(
      ValidatorForm.validateConfirmPassword('clave1234', 'clave1234'),
      isNull,
    );
  });

  test('validateRequired devuelve el mensaje dado', () {
    expect(ValidatorForm.validateRequired(' ', 'Falta'), 'Falta');
    expect(ValidatorForm.validateRequired('Ana', 'Falta'), isNull);
  });

  test('validateText exige texto y respeta el máximo', () {
    expect(
      ValidatorForm.validateText(' ', mensaje: 'Falta', maximo: 5),
      'Falta',
    );
    expect(
      ValidatorForm.validateText('abcdef', mensaje: 'Falta', maximo: 5),
      'Máximo 5 caracteres',
    );
    expect(
      ValidatorForm.validateText('abc', mensaje: 'Falta', maximo: 5),
      isNull,
    );
  });

  test('validateSelection pide elegir una opción', () {
    expect(ValidatorForm.validateSelection<int>(null, 'Elige'), 'Elige');
    expect(ValidatorForm.validateSelection(3, 'Elige'), isNull);
  });

  test('validateCodigo exige los 6 dígitos', () {
    expect(ValidatorForm.validateCodigo(''), 'Ingresa el código');
    expect(ValidatorForm.validateCodigo('123'), 'El código tiene 6 dígitos');
    expect(ValidatorForm.validateCodigo('12a456'), isNotNull);
    expect(ValidatorForm.validateCodigo('123456'), isNull);
  });

  test('validateCodigoEstudiante es opcional pero sin símbolos', () {
    expect(ValidatorForm.validateCodigoEstudiante(''), isNull);
    expect(ValidatorForm.validateCodigoEstudiante('2021-0045'), isNull);
    expect(ValidatorForm.validateCodigoEstudiante('20@21'), isNotNull);
  });
}
