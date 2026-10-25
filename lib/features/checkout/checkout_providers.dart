import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_failure.dart';
import '../../core/network/supabase_providers.dart';
import '../cart/cart_providers.dart';
import '../cart/data/mock_cart_repository.dart';
import 'data/mock_checkout_repository.dart';
import 'data/supabase_checkout_repository.dart';
import 'domain/checkout_models.dart';
import 'domain/checkout_repository.dart';
import 'presentation/payment_launcher.dart';

/// Con el mock del carrito usa el mock del checkout; si no, la Edge Function.
final checkoutRepositoryProvider = Provider<CheckoutRepository>((ref) {
  final cart = ref.watch(cartRepositoryProvider);
  if (cart is MockCartRepository) return MockCheckoutRepository(cart);
  return SupabaseCheckoutRepository.fromClient(ref.watch(supabaseClientProvider));
});

/// Sin backend no hay Wompi: se simula el resultado.
final paymentLauncherProvider = Provider<PaymentLauncher>(
  (ref) => ref.watch(checkoutRepositoryProvider) is MockCheckoutRepository
      ? const SimulatedPaymentLauncher()
      : const WompiPaymentLauncher(),
);

/// Espera entre consultas mientras el pago sigue pendiente justo después de
/// volver de Wompi (PSE y Nequi tardan unos segundos en confirmar).
final checkoutPollIntervalProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 2),
);

enum CheckoutStep {
  /// Llenando dirección y contacto.
  form,

  /// Creando el intento de pago.
  starting,

  /// El cliente está en la pasarela.
  paying,

  /// Consultando el resultado.
  verifying,

  /// Hay un resultado: aprobado, pendiente o rechazado.
  done,
}

class CheckoutFlow {
  const CheckoutFlow({
    this.step = CheckoutStep.form,
    this.session,
    this.result,
    this.failure,
  });

  final CheckoutStep step;
  final CheckoutSession? session;
  final CheckoutStatus? result;

  /// Error del último paso: al iniciar se muestra sobre el formulario; al
  /// verificar, en el resultado.
  final AppFailure? failure;

  bool get isBusy =>
      step == CheckoutStep.starting ||
      step == CheckoutStep.paying ||
      step == CheckoutStep.verifying;
}

final checkoutControllerProvider =
    NotifierProvider.autoDispose<CheckoutController, CheckoutFlow>(
      CheckoutController.new,
    );

class CheckoutController extends Notifier<CheckoutFlow> {
  /// Consultas con el pago pendiente antes de mostrar "esperando confirmación".
  static const pendingChecks = 3;

  CheckoutRepository get _repository => ref.read(checkoutRepositoryProvider);

  @override
  CheckoutFlow build() => const CheckoutFlow();

  /// Crea el intento de pago. Devuelve `null` si falló; el error queda en el
  /// estado. Si el carrito cambió, se recarga para que el cliente lo vea.
  Future<CheckoutSession?> start({
    required String addressId,
    required CheckoutContact contact,
    required int expectedTotalCents,
  }) async {
    state = const CheckoutFlow(step: CheckoutStep.starting);
    try {
      final session = await _repository.start(
        addressId: addressId,
        contact: contact,
        expectedTotalCents: expectedTotalCents,
      );
      state = CheckoutFlow(step: CheckoutStep.paying, session: session);
      return session;
    } on AppFailure catch (failure) {
      if (failure is PriceChangedFailure ||
          failure is CartChangedFailure ||
          failure is CartEmptyFailure) {
        ref.invalidate(cartControllerProvider);
      }
      state = CheckoutFlow(failure: failure);
      return null;
    }
  }

  /// Consulta el resultado del intento actual. Con [transactionId] (el que
  /// Wompi devuelve al volver) y el pago aún pendiente, vuelve a consultar
  /// unas veces antes de dar el resultado.
  Future<void> verify({String? transactionId}) async {
    final session = state.session;
    if (session == null) return;
    state = CheckoutFlow(step: CheckoutStep.verifying, session: session);
    try {
      var result = await _repository.status(
        session.reference,
        transactionId: transactionId,
      );
      for (var check = 1;
          check < pendingChecks &&
              transactionId != null &&
              result.status == PaymentStatus.pending;
          check++) {
        await Future<void>.delayed(ref.read(checkoutPollIntervalProvider));
        result = await _repository.status(
          session.reference,
          transactionId: transactionId,
        );
      }
      if (result.status == PaymentStatus.approved) {
        // El backend sacó lo comprado del carrito.
        ref.invalidate(cartControllerProvider);
      }
      state = CheckoutFlow(
        step: CheckoutStep.done,
        session: session,
        result: result,
      );
    } on AppFailure catch (failure) {
      state = CheckoutFlow(
        step: CheckoutStep.done,
        session: session,
        failure: failure,
      );
    }
  }

  /// Vuelve al formulario para intentar de nuevo con un intento nuevo.
  void retry() => state = const CheckoutFlow();
}
