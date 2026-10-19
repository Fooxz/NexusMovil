import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/core/errors/app_failure.dart';
import 'package:prueba01/features/cart/data/cart_json.dart';
import 'package:prueba01/features/cart/domain/cart_models.dart';
import 'package:prueba01/features/catalog/domain/product.dart';

CartItem item(
  String offerId, {
  String provider = 'p1',
  int quantity = 1,
  int max = 10,
  bool available = true,
  int price = 100000,
}) => CartItem(
  offerId: offerId,
  quantity: quantity,
  maxQuantity: max,
  isAvailable: available,
  unitPriceCents: price,
  stockLevel: available ? StockLevel.stable : StockLevel.outOfStock,
  providerId: provider,
  providerName: 'Proveedor $provider',
  productId: 'product-$offerId',
  productName: 'Producto $offerId',
  brand: 'Marca',
);

void main() {
  test('groups lines by provider in order of first appearance', () {
    final state = CartState([
      item('a', provider: 'p2'),
      item('b', provider: 'p1'),
      item('c', provider: 'p2'),
    ]);

    expect(state.groups.map((g) => g.providerId), ['p2', 'p1']);
    expect(state.groups.first.items.map((i) => i.offerId), ['a', 'c']);
  });

  test('totals only count lines that can be paid', () {
    final state = CartState([
      item('ok', quantity: 2, price: 100000),
      item('gone', available: false, price: 999900),
      item('too-many', quantity: 5, max: 3, price: 50000),
    ]);

    expect(state.totalUnits, 8, reason: 'el contador muestra todo');
    expect(state.purchasableUnits, 2);
    expect(state.subtotalCents, 200000);
    expect(state.hasIssues, isTrue);
    expect(state.canCheckout, isFalse);
  });

  test('a clean cart can check out', () {
    final state = CartState([item('ok', quantity: 3, max: 3)]);

    expect(state.canCheckout, isTrue);
    expect(state.items.single.canIncrease, isFalse);
    expect(state.items.single.canDecrease, isTrue);
    expect(CartState.empty().canCheckout, isFalse);
  });

  test('reads a cart line of the contract', () {
    final items = cartItemsFromJson({
      'items': [
        {
          'offerId': 'off-1',
          'quantity': 2,
          'maxQuantity': 3,
          'available': true,
          'priceCents': 50000,
          'oldPriceCents': 60000,
          'stockLevel': 'critical',
          'providerId': 'prov-1',
          'providerName': 'TecnoPartes',
          'productId': 'gpu-1',
          'productName': 'GPU',
          'brand': 'NVIDIA',
          'category': 'gpu',
          'imageUrl': null,
          'campoNuevo': true,
        },
      ],
    });

    final line = items.single;
    expect(line.subtotalCents, 100000);
    expect(line.hasDiscount, isTrue);
    expect(line.stockLevel, StockLevel.critical);
    expect(line.category, ProductCategory.gpu);
    expect(() => cartItemsFromJson({'items': [{}]}), throwsFormatException);
  });

  test('QUANTITY_UNAVAILABLE carries the maximum in details', () {
    final failure = AppFailure.fromApiError(
      statusCode: 409,
      code: 'QUANTITY_UNAVAILABLE',
      details: '{"maxQuantity" : 3}',
    );

    expect(failure, isA<QuantityUnavailableFailure>());
    expect((failure as QuantityUnavailableFailure).maxQuantity, 3);
    expect(failure.userMessage, 'Solo puedes llevar 3 unidades de este producto.');
    expect(
      AppFailure.fromApiError(code: 'QUANTITY_UNAVAILABLE', details: 'no es json'),
      isA<QuantityUnavailableFailure>(),
    );
    expect(AppFailure.fromApiError(code: 'OUT_OF_STOCK'), isA<OutOfStockFailure>());
    expect(AppFailure.fromApiError(code: 'AUTH_REQUIRED'), isA<UnauthorizedFailure>());
    expect(AppFailure.fromApiError(code: 'OFFER_NOT_FOUND'), isA<NotFoundFailure>());
  });
}
