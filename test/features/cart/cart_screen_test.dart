import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/features/cart/cart_providers.dart';
import 'package:prueba01/features/cart/domain/cart_models.dart';
import 'package:prueba01/features/cart/domain/cart_repository.dart';
import 'package:prueba01/features/cart/presentation/cart_screen.dart';

import '../../support/auth_test_support.dart' show tapAndSettle, usePhoneViewport;
import '../../support/cart_test_support.dart';
import 'cart_models_test.dart' show item;

void main() {
  late CartTestBed bed;

  setUp(() => bed = CartTestBed());

  Future<CartController> pumpCart(WidgetTester tester, {Widget? home}) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(bed.app(home: home ?? const CartScreen()));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(CartScreen)),
    ).read(cartControllerProvider.notifier);
  }

  testWidgets('an empty cart invites to keep shopping', (tester) async {
    await pumpCart(tester);

    expect(find.text('Tu carrito está vacío.'), findsOneWidget);
    expect(find.text('Seguir comprando'), findsOneWidget);
  });

  testWidgets('groups lines by provider and totals them', (tester) async {
    final cart = await pumpCart(tester);
    await cart.add(MockOffers.rtx5090Few);
    await cart.add(MockOffers.ryzen, quantity: 2);
    await tester.pumpAndSettle();

    expect(find.text('Tu pedido llegará en 2 envíos, uno por proveedor.'), findsOneWidget);
    expect(find.text('VENDIDO Y DESPACHADO POR MUNDO PC'), findsOneWidget);
    expect(find.text('VENDIDO Y DESPACHADO POR TIENDA DEMO'), findsOneWidget);
    expect(find.text('Inicia sesión para guardar tu carrito y comprar.'), findsOneWidget);
    // 8.150.000 + 2 × 2.596.000 = 13.342.000
    expect(find.text('\$13.342.000'), findsNWidgets(2), reason: 'subtotal y total');
  });

  testWidgets('the stepper stops at the available units', (tester) async {
    final cart = await pumpCart(tester);
    await cart.add(MockOffers.rtx5090Few);
    await tester.pumpAndSettle();

    await tapAndSettle(tester, find.byTooltip('Agregar una unidad'));
    await tapAndSettle(tester, find.byTooltip('Agregar una unidad'));

    expect(find.text('03'), findsOneWidget);
    expect(find.text('Puedes llevar hasta 3 unidades.'), findsOneWidget);
    final plus = tester.widget<IconButton>(
      find.ancestor(of: find.byIcon(Icons.add), matching: find.byType(IconButton)),
    );
    expect(plus.onPressed, isNull);
  });

  testWidgets('removes a line and clears after confirming', (tester) async {
    final cart = await pumpCart(tester);
    await cart.add(MockOffers.rtx5090Few);
    await cart.add(MockOffers.ryzen);
    await tester.pumpAndSettle();

    await tapAndSettle(tester, find.byTooltip('Quitar del carrito').first);
    expect(find.text('VENDIDO Y DESPACHADO POR MUNDO PC'), findsNothing);

    await tapAndSettle(tester, find.text('Vaciar carrito'));
    await tapAndSettle(tester, find.text('Vaciar'));
    expect(find.text('Tu carrito está vacío.'), findsOneWidget);
  });

  testWidgets('confirming without a session opens the login', (tester) async {
    final cart = await pumpCart(tester);
    await cart.add(MockOffers.ryzen);
    await tester.pumpAndSettle();

    await tapAndSettle(tester, find.text('Confirmar pedido'));

    expect(find.text('Inicia sesión para confirmar tu pedido.'), findsOneWidget);
  });

  testWidgets('lines that changed are flagged and can be adjusted', (tester) async {
    await bed.createAccount();
    final repository = _FixedCartRepository([
      item('a', quantity: 5, max: 2, provider: 'p1'),
      item('b', available: false, provider: 'p1'),
    ]);
    usePhoneViewport(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...bed.overrides,
          cartRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: CartScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Solo quedan 2 unidades.'), findsOneWidget);
    expect(
      find.text('Ya no está disponible y no se incluirá en tu pedido.'),
      findsOneWidget,
    );
    expect(find.text('Revisa los productos marcados antes de confirmar.'), findsOneWidget);
    final confirm = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Confirmar pedido'),
    );
    expect(confirm.onPressed, isNull, reason: 'no se confirma con líneas por revisar');

    await tapAndSettle(tester, find.text('Ajustar a 2'));

    expect(find.text('Solo quedan 2 unidades.'), findsNothing);
    expect(repository.lastSet, ('a', 2));
  });
}

/// Carrito guardado con líneas fijas, para casos que el mock no produce
/// (stock que bajó después de agregar).
class _FixedCartRepository implements CartRepository {
  _FixedCartRepository(this.items);

  List<CartItem> items;
  (String, int)? lastSet;

  @override
  Future<List<CartItem>> load() async => items;

  @override
  Future<List<CartItem>> setQuantity(String offerId, int quantity) async {
    lastSet = (offerId, quantity);
    items = [
      for (final line in items)
        line.offerId == offerId
            ? item(
                line.offerId,
                quantity: quantity,
                max: line.maxQuantity,
                provider: line.providerId,
              )
            : line,
    ];
    return items;
  }

  @override
  Future<List<CartItem>> preview(List<CartEntry> entries) async => const [];
  @override
  Future<List<CartItem>> add(String offerId, int quantity) async => items;
  @override
  Future<List<CartItem>> remove(String offerId) async => items;
  @override
  Future<List<CartItem>> clear() async => items = const [];
  @override
  Future<List<CartItem>> merge(List<CartEntry> entries) async => items;
}
