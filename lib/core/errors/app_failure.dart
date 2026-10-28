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
  ///
  /// [message] solo se muestra en los `VALIDATION_ERROR` que traen el campo
  /// en `details` (`{"field": ...}`, partes 7 y 8): son textos del backend
  /// escritos para el usuario.
  factory AppFailure.fromApiError({
    int? statusCode,
    String? code,
    Object? details,
    String? message,
  }) {
    return switch ((statusCode, code)) {
      // --- Roles y tiendas (partes 7 y 8) ---
      (_, 'FORBIDDEN') || (_, 'PROVIDER_REQUIRED') => const ForbiddenFailure(),
      (_, 'PROVIDER_NOT_ACTIVE') => const StoreNotActiveFailure(),
      (_, 'PASSWORD_CHANGE_REQUIRED') => const PasswordChangeRequiredFailure(),
      (_, 'CONSENT_REQUIRED') => const DocumentsPendingFailure(),
      (_, 'CUSTOMER_ONLY') => const CustomerOnlyFailure(),
      (_, 'PRODUCT_EXISTS') => ProductExistsFailure(
        productId: _stringFrom(details, 'productId'),
        productName: _stringFrom(details, 'name'),
      ),
      (_, 'POSSIBLE_DUPLICATE') => PossibleDuplicateFailure(
        _candidatesFrom(details),
      ),
      (_, 'PRODUCT_SHARED') => const ProductSharedFailure(),
      (_, 'PRODUCT_LOCKED') => const ProductLockedFailure(),
      (_, 'OFFER_EXISTS') => const OfferExistsFailure(),
      (_, 'OFFER_RETIRED') => const OfferRetiredFailure(),
      (_, 'INVALID_TRANSITION') => const InvalidOrderTransitionFailure(),
      (_, 'SIMILAR_STORE_NAME') => SimilarStoreNameFailure(
        _stringFrom(details, 'displayName'),
      ),
      (_, 'TAX_ID_TAKEN') => const TaxIdTakenFailure(),
      (_, 'EMAIL_EXISTS') => const StoreEmailTakenFailure(),
      (_, 'PROVIDER_HAS_ACCOUNT') => const StoreHasAccountFailure(),
      (_, 'AUTH_UNAVAILABLE') => const AccountServiceFailure(),
      (_, 'VALIDATION_ERROR')
          when message != null && _stringFrom(details, 'field') != null =>
        FieldValidationFailure(
          field: _stringFrom(details, 'field')!,
          message: message,
        ),
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
      (_, 'PROVIDER_NOT_FOUND') ||
      (404, _) => const NotFoundFailure(),
      (_, 'VALIDATION_ERROR') || (400, _) => const ValidationFailure(),
      (401, _) || (403, _) => const UnauthorizedFailure(),
      _ => const UnexpectedFailure(),
    };
  }

  /// `details` como mapa: llega como objeto o como JSON en texto.
  static Map<Object?, Object?>? _detailsMap(Object? details) {
    Object? value = details;
    if (value is String) {
      try {
        value = jsonDecode(value);
      } on FormatException {
        return null;
      }
    }
    return value is Map ? value : null;
  }

  /// Un entero de `details`.
  static int? _intFrom(Object? details, String key) {
    final value = _detailsMap(details)?[key];
    return value is int ? value : null;
  }

  /// Un texto de `details`.
  static String? _stringFrom(Object? details, String key) {
    final value = _detailsMap(details)?[key];
    return value is String ? value : null;
  }

  /// Productos parecidos de `POSSIBLE_DUPLICATE`.
  static List<DuplicateCandidate> _candidatesFrom(Object? details) {
    final candidates = _detailsMap(details)?['candidates'];
    return [
      if (candidates is List)
        for (final candidate in candidates)
          if (candidate case {
            'productId': String productId,
            'name': String name,
          })
            DuplicateCandidate(
              productId: productId,
              name: name,
              model: candidate['model'] is String
                  ? candidate['model'] as String
                  : null,
            ),
    ];
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

// --- Roles y tiendas (API_CONTRATO, partes 7 y 8) ---

/// La cuenta no tiene el rol que pide la función (administrador o tienda).
class ForbiddenFailure extends AppFailure {
  const ForbiddenFailure() : super('Tu cuenta no tiene permiso para esta acción.');
}

class StoreNotActiveFailure extends AppFailure {
  const StoreNotActiveFailure()
    : super('Tu tienda no está habilitada. Comunícate con NEXUS.');
}

class PasswordChangeRequiredFailure extends AppFailure {
  const PasswordChangeRequiredFailure()
    : super('Cambia tu contraseña temporal para continuar.');
}

/// Hay versiones vigentes de los documentos legales sin aceptar.
class DocumentsPendingFailure extends AppFailure {
  const DocumentsPendingFailure()
    : super('Acepta los términos y la política de datos vigentes para continuar.');
}

/// Roles exclusivos: solo los clientes compran.
class CustomerOnlyFailure extends AppFailure {
  const CustomerOnlyFailure()
    : super('Las cuentas de tienda y de administración no compran en NEXUS.');
}

/// El producto ya está en el catálogo: la tienda publica su oferta sobre él.
class ProductExistsFailure extends AppFailure {
  const ProductExistsFailure({this.productId, this.productName})
    : super('Este producto ya está en el catálogo. Publica tu oferta sobre él.');

  final String? productId;
  final String? productName;
}

class DuplicateCandidate {
  const DuplicateCandidate({required this.productId, required this.name, this.model});

  final String productId;
  final String name;
  final String? model;
}

/// Hay productos parecidos de la misma marca: la tienda revisa o confirma
/// que es otro.
class PossibleDuplicateFailure extends AppFailure {
  const PossibleDuplicateFailure(this.candidates)
    : super('Puede que este producto ya esté en el catálogo. Revisa los parecidos o confirma que es otro.');

  final List<DuplicateCandidate> candidates;
}

class ProductSharedFailure extends AppFailure {
  const ProductSharedFailure()
    : super('Otras tiendas venden este producto: la ficha ya no se puede editar, solo tu oferta.');
}

class ProductLockedFailure extends AppFailure {
  const ProductLockedFailure()
    : super('Esta ficha es del catálogo compartido: solo puedes cambiar tu oferta.');
}

class OfferExistsFailure extends AppFailure {
  const OfferExistsFailure() : super('Ya tienes una oferta de este producto.');
}

class OfferRetiredFailure extends AppFailure {
  const OfferRetiredFailure()
    : super('La oferta está retirada. Vuelve a publicarla para editarla.');
}

/// Otra tienda tiene un nombre visible equivalente. Dos negocios distintos
/// pueden llamarse igual, así que el administrador puede confirmar.
class SimilarStoreNameFailure extends AppFailure {
  SimilarStoreNameFailure(this.existingName)
    : super(
        existingName == null
            ? 'Ya hay una tienda con un nombre parecido. Confirma si es otro negocio.'
            : 'Ya hay una tienda llamada $existingName. Confirma si es otro negocio.',
      );

  final String? existingName;
}

class TaxIdTakenFailure extends AppFailure {
  const TaxIdTakenFailure() : super('Ya hay una tienda con ese NIT.');
}

class StoreEmailTakenFailure extends AppFailure {
  const StoreEmailTakenFailure()
    : super('Ya existe una cuenta con ese correo. Usa otro para la tienda.');
}

class StoreHasAccountFailure extends AppFailure {
  const StoreHasAccountFailure() : super('Esa tienda ya tiene una cuenta.');
}

class AccountServiceFailure extends AppFailure {
  const AccountServiceFailure()
    : super('No se pudo completar la operación con la cuenta. Inténtalo de nuevo.');
}

/// Un dato no pasó una validación del backend. [message] es el texto del
/// backend para el usuario y [field], el campo (`priceCents`,
/// `attributes.socket`...).
class FieldValidationFailure extends AppFailure {
  const FieldValidationFailure({required this.field, required String message})
    : super(message);

  final String field;
}

// --- Panel de la tienda ---

/// El pedido ya no admite ese estado: otra persona lo cambió o la pantalla
/// quedó desactualizada.
class InvalidOrderTransitionFailure extends AppFailure {
  const InvalidOrderTransitionFailure()
    : super('El pedido cambió de estado. Actualízalo y vuelve a intentarlo.');
}
