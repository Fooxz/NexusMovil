import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/features/cart/cart_providers.dart';
import 'package:prueba01/features/catalog/presentation/catalog_screen.dart';
import 'package:prueba01/features/catalog/presentation/product_detail_screen.dart';

import '../../support/auth_test_support.dart' show tapAndSettle, usePhoneViewport;
import '../../support/cart_test_support.dart';

void main() {
  late CartTestBed bed;

  setUp(() => bed = CartTestBed());

  ProviderContainer containerOf(WidgetTester tester, Type screen) =>
      ProviderScope.containerOf(tester.element(find.byType(screen)));

  List<String> cartLines(WidgetTester tester, Type screen) => [
    for (final item
        in containerOf(tester, screen).read(cartControllerProvider).value!.items)
      '${item.offerId}:${item.quantity}',
  ];

  testWidgets('detail adds the chosen provider offer and quantity', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(
      bed.app(home: const ProductDetailScreen(productId: 'rtx-5090')),
    );
    await tester.pumpAndSettle();
    expect(find.text('COMPARAR TIENDAS'), findsOneWidget);

    await tapAndSettle(tester, find.text('Mundo PC'));
    await tapAndSettle(tester, find.byTooltip('Agregar una unidad'));
    await tapAndSettle(tester, find.byTooltip('Agregar una unidad'));
    await tapAndSettle(tester, find.text('AGREGAR AL CARRITO'));

    expect(find.text('3 unidades agregadas al carrito'), findsOneWidget);
    expect(cartLines(tester, ProductDetailScreen), ['${MockOffers.rtx5090Few}:3']);

    // Mundo PC solo tiene 3: una más supera lo disponible.
    await tapAndSettle(tester, find.byTooltip('Quitar una unidad'));
    await tapAndSettle(tester, find.byTooltip('Quitar una unidad'));
    await tapAndSettle(tester, find.text('AGREGAR AL CARRITO'));
    expect(
      find.text('Solo puedes llevar 3 unidades de este producto.'),
      findsOneWidget,
    );
  });

  testWidgets('buy now adds and opens the cart', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(
      bed.app(home: const ProductDetailScreen(productId: 'ryzen-9-9950x')),
    );
    await tester.pumpAndSettle();

    await tapAndSettle(tester, find.text('COMPRAR AHORA'));

    expect(find.text('CARRITO DE COMPRA'), findsOneWidget);
    expect(find.text('VENDIDO Y DESPACHADO POR TIENDA DEMO'), findsOneWidget);
  });

  testWidgets('an out-of-stock product cannot be added (HU-005)', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(
      bed.app(home: const ProductDetailScreen(productId: 'kraken-elite-360')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Agotado: por ahora no se puede agregar al carrito.'), findsOneWidget);
    for (final label in ['AGREGAR AL CARRITO', 'COMPRAR AHORA']) {
      final button = tester.widget<ButtonStyleButton>(
        find.ancestor(of: find.text(label), matching: find.byWidgetPredicate(
          (widget) => widget is ButtonStyleButton,
        )),
      );
      expect(button.onPressed, isNull, reason: label);
    }
  });

  testWidgets('the catalog card adds the best offer and the badge counts it', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(bed.app(home: const CatalogScreen()));
    await tester.pumpAndSettle();
    expect(find.byType(Badge), findsOneWidget);
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);

    await tapAndSettle(tester, find.byTooltip('Agregar al carrito').first);

    expect(find.text('Agregado al carrito'), findsOneWidget);
    expect(cartLines(tester, CatalogScreen), ['${MockOffers.rtx5090Plenty}:1']);

    // La barra con el ícono está dentro del scroll: se vuelve arriba.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 2000));
    await tester.pumpAndSettle();
    final badge = tester.widget<Badge>(find.byType(Badge));
    expect(badge.isLabelVisible, isTrue);
    expect(find.descendant(of: find.byType(Badge), matching: find.text('1')), findsOneWidget);
  });
}
