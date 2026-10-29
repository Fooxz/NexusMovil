import 'checkout_models.dart';

/// Checkout y pago (HU-010, HU-011). Exige sesión (RN-027). Los errores
/// llegan como `AppFailure`: `PriceChangedFailure`, `CartChangedFailure`,
/// `CartEmptyFailure` o `PaymentsUnavailableFailure`, entre otros.
abstract class CheckoutRepository {
  /// Revalida el carrito guardado y crea el intento de pago (RF-055).
  /// [expectedTotalCents] es el total que vio el cliente.
  Future<CheckoutSession> start({
    required String addressId,
    required CheckoutContact contact,
    required int expectedTotalCents,
  });

  /// Estado del intento. [transactionId] es el id del pago con el que vuelve
  /// Mercado Pago;
  /// con él, el backend confirma el resultado sin esperar el webhook.
  Future<CheckoutStatus> status(String reference, {String? transactionId});
}
