import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/core/errors/app_failure.dart';
import 'package:prueba01/features/cart/cart_providers.dart';
import 'package:prueba01/features/cart/presentation/cart_actions.dart';
import 'package:prueba01/features/cart/presentation/cart_screen.dart';
import 'package:prueba01/features/checkout/checkout_providers.dart';
import 'package:prueba01/features/checkout/data/mock_checkout_repository.dart';
import 'package:prueba01/features/checkout/domain/checkout_models.dart';
import 'package:prueba01/features/checkout/domain/checkout_repository.dart';
import 'package:prueba01/features/checkout/presentation/payment_launcher.dart';
import 'package:prueba01/features/profile/domain/profile_models.dart';
import 'package:prueba01/main.dart';

import '../../support/auth_test_support.dart' show enterField, tapAndSettle, usePhoneViewport;
import '../../support/cart_test_support.dart';

/// Pasarela falsa: devuelve [transactionId] como si el cliente volviera de Mercado Pago.
class _FakeLauncher implements PaymentLauncher {
  _FakeLauncher(this.transactionId);

  String? transactionId;
  final opened = <CheckoutSession>[];

  @override
  Future<String?> open(BuildContext context, CheckoutSession session) async {
    opened.add(session);
    return transactionId;
  }
}

class _PriceChangedRepository implements CheckoutRepository {
  @override
  Future<CheckoutSession> start({
    required String addressId,
    required CheckoutContact contact,
    required int expectedTotalCents,
  }) async => throw PriceChangedFailure(999900);

  @override
  Future<CheckoutStatus> status(String reference, {String? transactionId}) =>
      throw UnimplementedError();
}

void main() {
  late CartTestBed bed;
  late _FakeLauncher launcher;

  setUp(() async {
    bed = CartTestBed();
    launcher = _FakeLauncher(MockCheckoutRepository.approvedTransaction);
    await bed.createAccount();
  });

  Future<void> addAddress() => bed.profile.createAddress(
    const AddressInput(
      label: 'Casa',
      recipientName: 'Ana Pérez',
      phone: '3001234567',
      department: 'Cesar',
      city: 'Valledupar',
      addressLine: 'Calle 10 # 20-30',
    ),
  );

  /// Abre el carrito con [offers] y pasa al checkout con "Confirmar pedido".
  Future<void> openCheckout(
    WidgetTester tester, {
    List<String> offers = const [MockOffers.rtx5090Few, MockOffers.ryzen],
    CheckoutRepository? repository,
  }) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...bed.overrides,
          paymentLauncherProvider.overrideWithValue(launcher),
          checkoutPollIntervalProvider.overrideWithValue(Duration.zero),
          if (repository != null) checkoutRepositoryProvider.overrideWithValue(repository),
        ],
        retry: (retryCount, error) => null,
        child: MaterialApp(
          builder: (context, child) => CartBadgeHost(child: child!),
          onGenerateRoute: generateNexusRoute,
          home: const CartScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final cart = ProviderScope.containerOf(
      tester.element(find.byType(CartScreen)),
    ).read(cartControllerProvider.notifier);
    for (final offer in offers) {
      await cart.add(offer);
    }
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.text('Confirmar pedido'));
  }

  Future<void> fillAndPay(WidgetTester tester) async {
    await enterField(tester, '3001234567', '300 123 4567');
    await enterField(tester, 'Sin puntos ni espacios', '1065123456');
    await tapAndSettle(tester, find.text('PAGAR \$10.746.000'));
  }

  testWidgets('an approved payment shows the order split by provider', (tester) async {
    await addAddress();
    await openCheckout(tester);

    expect(find.text('FINALIZAR COMPRA'), findsOneWidget);
    expect(find.text('Casa · Ana Pérez'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Ana Pérez'), findsOneWidget,
        reason: 'el nombre viene del perfil');
    expect(find.text('Envío 1 de 2 · Mundo PC'), findsOneWidget);

    await fillAndPay(tester);

    expect(launcher.opened.single.amountCents, 1074600000);
    expect(find.text('¡Pago aprobado!'), findsOneWidget);
    expect(find.text('Orden NX-000001'), findsOneWidget);
    expect(find.text('MUNDO PC'), findsOneWidget);
    expect(find.text('TIENDA DEMO'), findsOneWidget);

    await tapAndSettle(tester, find.text('Seguir comprando'));
    expect(find.text('Tu carrito está vacío.'), findsOneWidget, reason: 'lo comprado sale del carrito');
  });

  testWidgets('a declined payment offers to retry with the same data', (tester) async {
    launcher.transactionId = MockCheckoutRepository.declinedTransaction;
    await addAddress();
    await openCheckout(tester);

    await fillAndPay(tester);
    expect(find.text('El pago no se aprobó'), findsOneWidget);

    await tapAndSettle(tester, find.text('Intentar de nuevo'));
    expect(find.text('FINALIZAR COMPRA'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '1065123456'), findsOneWidget);

    launcher.transactionId = MockCheckoutRepository.approvedTransaction;
    await tapAndSettle(tester, find.text('PAGAR \$10.746.000'));
    expect(find.text('¡Pago aprobado!'), findsOneWidget);
    expect(launcher.opened.map((s) => s.reference).toSet(), hasLength(2),
        reason: 'cada intento tiene su referencia');
  });

  testWidgets('closing the payment without paying keeps the cart', (tester) async {
    launcher.transactionId = null;
    await addAddress();
    await openCheckout(tester);

    await fillAndPay(tester);

    expect(find.text('Aún no recibimos tu pago'), findsOneWidget);
    expect(find.text('Ya pagué, consultar'), findsOneWidget);
    await tapAndSettle(tester, find.text('Intentar de nuevo'));
    expect(find.text('FINALIZAR COMPRA'), findsOneWidget);
  });

  testWidgets('asks for an address and validates the document', (tester) async {
    await openCheckout(tester);

    expect(find.text('Agregar una dirección'), findsOneWidget);
    await tapAndSettle(tester, find.text('PAGAR \$10.746.000'));
    expect(find.text('Escribe tu número de documento.'), findsOneWidget);
    expect(launcher.opened, isEmpty);

    await enterField(tester, '3001234567', '3001234567');
    await enterField(tester, 'Sin puntos ni espacios', '1065123456');
    await tapAndSettle(tester, find.text('PAGAR \$10.746.000'));
    expect(find.text('Agrega una dirección de entrega.'), findsOneWidget);
    expect(launcher.opened, isEmpty);
  });

  testWidgets('a changed total is shown before paying', (tester) async {
    await addAddress();
    await openCheckout(tester, repository: _PriceChangedRepository());

    await fillAndPay(tester);

    expect(find.textContaining('El total de tu carrito cambió a \$9.999'), findsOneWidget);
    expect(launcher.opened, isEmpty);
    expect(find.text('FINALIZAR COMPRA'), findsOneWidget);
  });
}
