import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/core/utils/validators.dart';

void main() {
  test('email', () {
    expect(Validators.email(''), isNotNull);
    expect(Validators.email('ana@'), isNotNull);
    expect(Validators.email('ana pérez@correo.com'), isNotNull);
    expect(Validators.email(' ana@correo.com '), isNull);
  });

  test('password follows the Supabase policy: 8+ chars, letters and digits', () {
    expect(Validators.password('Corta1'), 'Usa al menos 8 caracteres.');
    expect(Validators.password('solamenteletras'), 'Combina letras y números.');
    expect(Validators.password('12345678'), 'Combina letras y números.');
    expect(Validators.password('Nexus12345'), isNull);
    expect(Validators.password('contraseña1'), isNull);
  });

  test('matches compares against the current value of the other field', () {
    var other = 'abc';
    final validator = Validators.matches(() => other);
    expect(validator('abc'), isNull);
    other = 'xyz';
    expect(validator('abc'), isNotNull);
  });

  test('text checks trimmed length', () {
    final validator = Validators.text(field: 'tu nombre', min: 2, max: 5);
    expect(validator('   '), 'Completa tu nombre.');
    expect(validator(' a '), contains('al menos 2'));
    expect(validator('abcdef'), contains('hasta 5'));
    expect(validator(' ab '), isNull);
  });

  test('phone accepts 7 to 15 digits ignoring separators', () {
    expect(Validators.phone('300 123 4567'), isNull);
    expect(Validators.phone('+57 (300) 123-4567'), isNull);
    expect(Validators.phone('12345'), isNotNull);
    expect(Validators.phone('30012abc'), isNotNull);
    expect(Validators.optionalPhone(''), isNull);
    expect(Validators.optionalPhone('12'), isNotNull);
    expect(Validators.normalizePhone('+57 (300) 123-4567'), '+573001234567');
  });

  test('code needs exactly 6 digits', () {
    expect(Validators.code('123456'), isNull);
    expect(Validators.code('12345'), isNotNull);
    expect(Validators.code('12a456'), isNotNull);
  });
}
