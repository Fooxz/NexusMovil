/// Errores que los repositorios devuelven a los controladores.
///
/// Los repositorios de `data/` traducen las excepciones de red o de Supabase a
/// un `AppFailure`; los controladores y las pantallas nunca ven una excepción
/// de infraestructura. `userMessage` es el texto en español para la interfaz.
sealed class AppFailure implements Exception {
  const AppFailure(this.userMessage);

  final String userMessage;

  /// Convierte el cuerpo de error del contrato (`docs/API_CONTRATO.md`,
  /// sección 4) en un `AppFailure`. Depende del código HTTP y de `code`;
  /// `message` es solo informativo y no se muestra al usuario.
  factory AppFailure.fromApiError({int? statusCode, String? code}) {
    return switch ((statusCode, code)) {
      (_, 'PRODUCT_NOT_FOUND') || (404, _) => const NotFoundFailure(),
      (_, 'VALIDATION_ERROR') || (400, _) => const ValidationFailure(),
      (401, _) || (403, _) => const UnauthorizedFailure(),
      _ => const UnexpectedFailure(),
    };
  }

  @override
  String toString() => userMessage;
}

class NetworkFailure extends AppFailure {
  const NetworkFailure()
    : super('No hay conexión. Revisa tu red e inténtalo de nuevo.');
}

class NotFoundFailure extends AppFailure {
  const NotFoundFailure() : super('No encontramos lo que buscas.');
}

class ValidationFailure extends AppFailure {
  const ValidationFailure()
    : super('Algunos datos no son válidos. Revísalos e inténtalo de nuevo.');
}

class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure() : super('Inicia sesión para continuar.');
}

class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure()
    : super('Ocurrió un error inesperado. Inténtalo de nuevo.');
}

// --- Cuentas (fase 4) ---

class InvalidCredentialsFailure extends AppFailure {
  const InvalidCredentialsFailure()
    : super('El correo o la contraseña no son correctos.');
}

class EmailAlreadyRegisteredFailure extends AppFailure {
  const EmailAlreadyRegisteredFailure()
    : super('Ya existe una cuenta con ese correo. Inicia sesión o recupera tu acceso.');
}

class WeakPasswordFailure extends AppFailure {
  const WeakPasswordFailure()
    : super('La contraseña debe tener al menos 8 caracteres, con letras y números.');
}

class ConsentRequiredFailure extends AppFailure {
  const ConsentRequiredFailure()
    : super('Debes aceptar los términos y la política de datos para crear tu cuenta.');
}

class InvalidCodeFailure extends AppFailure {
  const InvalidCodeFailure()
    : super('El código no es válido o ya venció. Pide uno nuevo.');
}

class RateLimitedFailure extends AppFailure {
  const RateLimitedFailure()
    : super('Hiciste demasiados intentos. Espera un momento e inténtalo de nuevo.');
}
