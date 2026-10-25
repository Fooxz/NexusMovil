/// Validadores de formulario. Devuelven el mensaje de error en español o
/// `null` si el valor es válido. Siguen las mismas reglas que el backend
/// (`backend/supabase/config.toml` y las restricciones de las tablas), para
/// que el usuario vea el error antes de enviar.
abstract final class Validators {
  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final _phone = RegExp(r'^\+?[0-9]{7,15}$');
  static final _letter = RegExp(r'[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]');
  static final _digit = RegExp(r'[0-9]');

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Escribe tu correo.';
    if (!_email.hasMatch(text)) return 'Escribe un correo válido.';
    return null;
  }

  /// Política de Supabase Auth: 8 caracteres como mínimo, con letras y números.
  static String? password(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Escribe una contraseña.';
    if (text.length < 8) return 'Usa al menos 8 caracteres.';
    if (!_letter.hasMatch(text) || !_digit.hasMatch(text)) {
      return 'Combina letras y números.';
    }
    return null;
  }

  /// Para iniciar sesión solo se exige que no esté vacía.
  static String? requiredPassword(String? value) =>
      (value ?? '').isEmpty ? 'Escribe tu contraseña.' : null;

  static String? Function(String?) matches(
    String Function() other, {
    String message = 'Las contraseñas no coinciden.',
  }) => (value) => value == other() ? null : message;

  static String? Function(String?) text({
    required String field,
    int min = 1,
    int max = 200,
  }) => (value) {
    final length = value?.trim().length ?? 0;
    if (length == 0) return 'Completa $field.';
    if (length < min) return '$field debe tener al menos $min caracteres.';
    if (length > max) return '$field admite hasta $max caracteres.';
    return null;
  };

  static String? optionalText(String? value, {int max = 200}) =>
      (value?.length ?? 0) > max ? 'Admite hasta $max caracteres.' : null;

  /// Teléfono de 7 a 15 dígitos, con `+` opcional. Ignora espacios y guiones.
  static String? phone(String? value) {
    final text = normalizePhone(value ?? '');
    if (text.isEmpty) return 'Escribe un teléfono.';
    if (!_phone.hasMatch(text)) return 'Escribe un teléfono de 7 a 15 dígitos.';
    return null;
  }

  static String? optionalPhone(String? value) =>
      normalizePhone(value ?? '').isEmpty ? null : phone(value);

  /// Número de documento para facturar: de 4 a 20 letras o números. Ignora
  /// puntos, espacios y guiones, como `start_checkout`.
  static String? document(String? value) {
    final text = (value ?? '').replaceAll(RegExp(r'[\s.\-]'), '');
    if (text.isEmpty) return 'Escribe tu número de documento.';
    if (!RegExp(r'^[0-9A-Za-z]{4,20}$').hasMatch(text)) {
      return 'Escribe un documento de 4 a 20 letras o números.';
    }
    return null;
  }

  static String? code(String? value) {
    final text = value?.trim() ?? '';
    return RegExp(r'^[0-9]{6}$').hasMatch(text)
        ? null
        : 'Escribe el código de 6 dígitos.';
  }

  static String normalizePhone(String value) =>
      value.replaceAll(RegExp(r'[\s\-().]'), '');
}
