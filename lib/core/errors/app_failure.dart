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
