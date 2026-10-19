import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/core/errors/app_failure.dart';
import 'package:prueba01/features/cart/cart_providers.dart';
import 'package:prueba01/features/cart/domain/cart_models.dart';

import '../../support/cart_test_support.dart';

void main() {
  late CartTestBed bed;
  late ProviderContainer container;

  setUp(() {
    bed = CartTestBed();
    container = bed.container();
    addTearDown(container.dispose);
    // Mantiene vivo el carrito, como lo hace el contador en la app.
    container.listen(cartControllerProvider, (_, _) {});
  });

  CartController controller() => container.read(cartControllerProvider.notifier);

  /// Espera a que el carrito termine de recalcularse.
  Future<CartState> cart() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    return container.read(cartControllerProvider.future);
  }

  Future<List<String>> lines() async => [
    for (final item in (await cart()).items) '${item.offerId}:${item.quantity}',
  ];

  group('without a session', () {
    test('adds lines and applies the stock limits', () async {
      expect((await cart()).isEmpty, isTrue);

      await controller().add(MockOffers.rtx5090Few, quantity: 2);
      expect(await lines(), ['${MockOffers.rtx5090Few}:2']);

      await expectLater(
        controller().add(MockOffers.rtx5090Few, quantity: 2),
        throwsA(
          isA<QuantityUnavailableFailure>().having((f) => f.maxQuantity, 'max', 3),
        ),
      );
      await expectLater(
        controller().add(MockOffers.krakenOutOfStock),
        throwsA(isA<OutOfStockFailure>()),
      );
      await expectLater(controller().add('no-existe'), throwsA(isA<NotFoundFailure>()));
      expect(await lines(), ['${MockOffers.rtx5090Few}:2']);
    });

    test('changes quantities, removes and clears', () async {
      await controller().add(MockOffers.ryzen);
      await controller().add(MockOffers.rtx5090Plenty);
      await controller().setQuantity(MockOffers.ryzen, 4);
      expect(await lines(), ['${MockOffers.ryzen}:4', '${MockOffers.rtx5090Plenty}:1']);

      await controller().remove(MockOffers.ryzen);
      expect(await lines(), ['${MockOffers.rtx5090Plenty}:1']);

      await controller().clear();
      expect((await cart()).isEmpty, isTrue);
    });
  });

  test('signing in adds the guest cart to the saved one', () async {
    await bed.createAccount();
    await controller().add(MockOffers.rtx5090Few, quantity: 2);
    await bed.auth.signOut();
    expect((await cart()).isEmpty, isTrue, reason: 'sin sesión no se ve el guardado');

    await controller().add(MockOffers.rtx5090Few, quantity: 3);
    await controller().add(MockOffers.ryzen);
    await bed.auth.signIn(email: 'ana@nexus.test', password: 'Nexus12345');

    // 2 guardadas + 3 de invitado = 5, limitado a las 3 disponibles.
    expect(await lines(), ['${MockOffers.rtx5090Few}:3', '${MockOffers.ryzen}:1']);
    expect(container.read(guestCartProvider), isEmpty);
  });

  test('with a session the saved cart validates every change', () async {
    await bed.createAccount();
    await cart();

    await controller().add(MockOffers.rtx5090Plenty, quantity: 9);
    await expectLater(
      controller().add(MockOffers.rtx5090Plenty, quantity: 2),
      throwsA(
        isA<QuantityUnavailableFailure>().having((f) => f.maxQuantity, 'max', 10),
      ),
    );
    await controller().setQuantity(MockOffers.rtx5090Plenty, 10);
    expect(await lines(), ['${MockOffers.rtx5090Plenty}:10']);
    expect(container.read(cartItemCountProvider), 10);
  });

  test('rapid increments are applied one after the other', () async {
    await bed.createAccount();
    await cart();

    await Future.wait([
      controller().add(MockOffers.ryzen),
      controller().add(MockOffers.ryzen),
      controller().add(MockOffers.ryzen),
    ]);

    expect(await lines(), ['${MockOffers.ryzen}:3']);
  });
}
