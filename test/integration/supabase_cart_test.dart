// Prueba de integración del carrito contra el Supabase local con seed.sql.
// Se salta sin configuración; ver supabase_catalog_test.dart para ejecutarla.
@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/core/config/env.dart';
import 'package:prueba01/core/errors/app_failure.dart';
import 'package:prueba01/features/auth/data/supabase_auth_repository.dart';
import 'package:prueba01/features/cart/data/supabase_cart_repository.dart';
import 'package:prueba01/features/cart/domain/cart_models.dart';
import 'package:prueba01/features/catalog/data/supabase_product_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../support/integration_support.dart';

// Ofertas de seed.sql.
const _z790Three = 'off-mp-z790hero'; // 3 unidades
const _rtx5090Many = 'off-tp-rtx5090'; // 12 unidades, tope 10
const _krakenOut = 'off-mp-kraken360'; // agotada
const _hiddenProvider = 'off-cn-vengeance32'; // proveedor pendiente

void main() {
  const env = AppEnv.fromEnvironment();
  final skip = integrationSkip(env);

  SupabaseClient newClient() => SupabaseClient(
    env.supabaseUrl,
    env.supabasePublishableKey,
    authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
  );

  final runId = DateTime.now().millisecondsSinceEpoch;

  Future<SupabaseCartRepository> signedInCart(String name) async {
    final client = newClient();
    final auth = SupabaseAuthRepository(client);
    await auth.signUp(
      fullName: name,
      email: '$name.$runId@nexus.test'.toLowerCase(),
      password: 'Nexus12345',
      acceptedDocuments: await auth.getCurrentLegalDocuments(),
    );
    return SupabaseCartRepository.fromClient(client);
  }

  List<String> lines(List<CartItem> items) => [
    for (final item in items) '${item.offerId}:${item.quantity}',
  ];

  test('the catalog exposes the best offer to add from a card', () async {
    final products = SupabaseProductRepository.fromClient(newClient());
    final rtx = await products.getById('rtx-5090');
    expect(rtx!.bestOfferId, _rtx5090Many);
  }, skip: skip);

  test('guest preview shows current price, provider and availability', () async {
    final cart = SupabaseCartRepository.fromClient(newClient());

    final items = await cart.preview(const [
      CartEntry(offerId: _rtx5090Many, quantity: 2),
      CartEntry(offerId: _krakenOut, quantity: 1),
      CartEntry(offerId: _hiddenProvider, quantity: 1),
    ]);

    expect(items.first.providerName, 'TecnoPartes');
    expect(items.first.maxQuantity, 10);
    expect(items.first.subtotalCents, 2 * 799600000);
    expect(items[1].isAvailable, isFalse, reason: 'agotada');
    expect(items[2].isAvailable, isFalse, reason: 'proveedor pendiente');

    await expectLater(cart.load(), throwsA(isA<UnauthorizedFailure>()));
  }, skip: skip);

  test('the saved cart enforces stock with clear errors', () async {
    final cart = await signedInCart('Ana');

    expect(lines(await cart.add(_z790Three, 2)), ['$_z790Three:2']);
    await expectLater(
      cart.add(_z790Three, 2),
      throwsA(
        isA<QuantityUnavailableFailure>().having((f) => f.maxQuantity, 'max', 3),
      ),
    );
    await expectLater(cart.add(_krakenOut, 1), throwsA(isA<OutOfStockFailure>()));
    await expectLater(cart.add('no-existe', 1), throwsA(isA<NotFoundFailure>()));
    await expectLater(cart.setQuantity(_rtx5090Many, 11), throwsA(isA<QuantityUnavailableFailure>()));

    expect(lines(await cart.setQuantity(_rtx5090Many, 10)), [
      '$_z790Three:2',
      '$_rtx5090Many:10',
    ]);
    expect(lines(await cart.remove(_z790Three)), ['$_rtx5090Many:10']);

    // Otro usuario no ve este carrito.
    final other = await signedInCart('Beto');
    expect(await other.load(), isEmpty);
    expect(lines(await cart.load()), ['$_rtx5090Many:10']);
  }, skip: skip);

  test('merging the guest cart caps at the stock and drops unavailable', () async {
    final cart = await signedInCart('Caro');
    await cart.add(_z790Three, 2);

    final merged = await cart.merge(const [
      CartEntry(offerId: _z790Three, quantity: 5),
      CartEntry(offerId: _krakenOut, quantity: 1),
      CartEntry(offerId: _rtx5090Many, quantity: 1),
    ]);

    expect(lines(merged), ['$_z790Three:3', '$_rtx5090Many:1']);
    expect(await cart.clear(), isEmpty);
  }, skip: skip);
}
