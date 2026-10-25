import 'dart:convert';

import '../utils/format_price.dart';

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
  ///
  /// [details] es el texto `details` del cuerpo: para `QUANTITY_UNAVAILABLE`
  /// trae el JSON `{"maxQuantity": n}` (API_CONTRATO, parte 2) y para
  /// `PRICE_CHANGED`, `{"totalCents": n}` (parte 5).
  factory AppFailure.fromApiError({
    int? statusCode,
    String? code,
    Object? details,
  }) {
    return switch ((statusCode, code)) {
      (_, 'OUT_OF_STOCK') => const OutOfStockFailure(),
      (_, 'QUANTITY_UNAVAILABLE') => QuantityUnavailableFailure(
        _intFrom(details, 'maxQuantity'),
      ),
      (_, 'AUTH_REQUIRED') => const UnauthorizedFailure(),
      (_, 'CART_EMPTY') => const CartEmptyFailure(),
      (_, 'CART_CHANGED') => const CartChangedFailure(),
      (_, 'PRICE_CHANGED') => PriceChangedFailure(_intFrom(details, 'totalCents')),
      (_, 'PAYMENTS_UNAVAILABLE') => const PaymentsUnavailableFailure(),
      (_, 'ASSISTANT_UNAVAILABLE') || (503, _) => const AssistantUnavailableFailure(),
      (_, 'RATE_LIMITED') || (429, _) => const RateLimitedFailure(),
      (_, 'PRODUCT_NOT_FOUND') ||
      (_, 'OFFER_NOT_FOUND') ||
      (404, _) => const NotFoundFailure(),
      (_, 'VALIDATION_ERROR') || (400, _) => const ValidationFailure(),
      (401, _) || (403, _) => const UnauthorizedFailure(),
      _ => const UnexpectedFailure(),
    };
  }

  /// Un entero de `details`, que llega como objeto o como JSON en texto.
  static int? _intFrom(Object? details, String key) {
    Object? value = details;
    if (value is String) {
      try {
        value = jsonDecode(value);
      } on FormatException {
        return null;
      }
    }
    return value is Map && value[key] is int ? value[key] as int : null;
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

// --- Carrito (fase 5) ---

class OutOfStockFailure extends AppFailure {
  const OutOfStockFailure() : super('Este producto ya no está disponible.');
}

/// La cantidad pedida supera lo disponible. [maxQuantity] es cuánto se puede
/// llevar, si el backend lo informó.
class QuantityUnavailableFailure extends AppFailure {
  QuantityUnavailableFailure(this.maxQuantity)
    : super(
        maxQuantity == null
            ? 'No hay suficientes unidades disponibles.'
            : maxQuantity == 1
            ? 'Solo puedes llevar 1 unidad de este producto.'
            : 'Solo puedes llevar $maxQuantity unidades de este producto.',
      );

  final int? maxQuantity;
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

// --- Asistente (fase 7) ---

/// El modelo de IA no respondió (caído o sin cuota). La app sigue funcionando:
/// se ofrece el catálogo y el PC Builder (RNF-018).
class AssistantUnavailableFailure extends AppFailure {
  const AssistantUnavailableFailure()
    : super(
        'El asistente no está disponible en este momento. Mientras tanto, '
        'puedes buscar en el catálogo o armar tu equipo en el PC Builder.',
      );
}

// --- Checkout (fase 8) ---

class CartEmptyFailure extends AppFailure {
  const CartEmptyFailure() : super('Tu carrito está vacío.');
}

/// Una línea se agotó o quedó con más unidades de las disponibles mientras el
/// cliente confirmaba (RF-055).
class CartChangedFailure extends AppFailure {
  const CartChangedFailure()
    : super('Algunos productos de tu carrito cambiaron. Revísalo antes de pagar.');
}

/// El total del carrito cambió desde que el cliente lo vio. [totalCents] es
/// el nuevo total, si el backend lo informó.
class PriceChangedFailure extends AppFailure {
  PriceChangedFailure(this.totalCents)
    : super(
        totalCents == null
            ? 'El total de tu carrito cambió. Revísalo antes de pagar.'
            : 'El total de tu carrito cambió a ${formatPrice(totalCents)}. '
                  'Revísalo antes de pagar.',
      );

  final int? totalCents;
}

/// La pasarela no está configurada o no responde. El carrito no se pierde.
class PaymentsUnavailableFailure extends AppFailure {
  const PaymentsUnavailableFailure()
    : super('Los pagos no están disponibles en este momento. Tu carrito sigue guardado.');
}
