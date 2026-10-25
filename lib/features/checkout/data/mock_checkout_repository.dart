import '../../../core/errors/app_failure.dart';
import '../../cart/data/mock_cart_repository.dart';
import '../../cart/domain/cart_models.dart';
import '../domain/checkout_models.dart';
import '../domain/checkout_repository.dart';

/// Checkout en memoria sobre el [MockCartRepository], con las mismas reglas
/// del backend: carrito sin cambios, total igual al que vio el cliente y
/// orden con una sub-orden por proveedor solo si el pago se aprueba.
///
/// Sin pasarela: `SimulatedPaymentLauncher` devuelve [approvedTransaction] o
/// [declinedTransaction] como si Wompi respondiera.
class MockCheckoutRepository implements CheckoutRepository {
  MockCheckoutRepository(this._cart);

  static const approvedTransaction = 'SIM-APPROVED';
  static const declinedTransaction = 'SIM-DECLINED';

  final MockCartRepository _cart;
  final _sessions = <String, ({int amountCents, List<CartItem> items})>{};
  final _results = <String, CheckoutStatus>{};
  var _nextReference = 1;
  var _nextOrder = 1;

  @override
  Future<CheckoutSession> start({
    required String addressId,
    required CheckoutContact contact,
    required int expectedTotalCents,
  }) async {
    final cart = CartState(await _cart.load());
    if (cart.isEmpty) throw const CartEmptyFailure();
    if (!cart.canCheckout) throw const CartChangedFailure();
    if (cart.subtotalCents != expectedTotalCents) {
      throw PriceChangedFailure(cart.subtotalCents);
    }

    final reference = 'NX-SIM-${_nextReference++}';
    _sessions[reference] = (amountCents: cart.subtotalCents, items: cart.items);
    return CheckoutSession(
      reference: reference,
      amountCents: cart.subtotalCents,
      checkoutUrl: Uri.parse('https://checkout.wompi.co/p/?reference=$reference'),
      redirectUrl: Uri.parse('https://nexus.invalid/checkout'),
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );
  }

  @override
  Future<CheckoutStatus> status(String reference, {String? transactionId}) async {
    if (_results[reference] case final result?
        when result.status == PaymentStatus.approved) {
      return result;
    }
    final session = _sessions[reference] ?? (throw const NotFoundFailure());

    final result = switch (transactionId) {
      approvedTransaction => CheckoutStatus(
        reference: reference,
        status: PaymentStatus.approved,
        amountCents: session.amountCents,
        transactionId: transactionId,
        paymentMethod: 'CARD',
        order: _placeOrder(session.amountCents, session.items),
      ),
      declinedTransaction => CheckoutStatus(
        reference: reference,
        status: PaymentStatus.declined,
        amountCents: session.amountCents,
        transactionId: transactionId,
        paymentMethod: 'CARD',
      ),
      _ =>
        _results[reference] ??
            CheckoutStatus(
              reference: reference,
              status: PaymentStatus.pending,
              amountCents: session.amountCents,
            ),
    };
    if (result.status == PaymentStatus.approved) {
      for (final item in session.items) {
        await _cart.remove(item.offerId);
      }
    }
    return _results[reference] = result;
  }

  PlacedOrder _placeOrder(int totalCents, List<CartItem> items) {
    final state = CartState(items);
    return PlacedOrder(
      id: 'order-$_nextOrder',
      number: 'NX-${(_nextOrder++).toString().padLeft(6, '0')}',
      totalCents: totalCents,
      createdAt: DateTime.now(),
      subOrders: [
        for (final group in state.groups)
          PlacedSubOrder(
            id: 'sub-${group.providerId}',
            providerName: group.providerName,
            subtotalCents: group.items.fold(0, (sum, item) => sum + item.subtotalCents),
            items: [
              for (final item in group.items)
                PlacedOrderItem(
                  productId: item.productId,
                  productName: item.productName,
                  brand: item.brand,
                  quantity: item.quantity,
                  unitPriceCents: item.unitPriceCents,
                  lineTotalCents: item.subtotalCents,
                ),
            ],
          ),
      ],
    );
  }
}
