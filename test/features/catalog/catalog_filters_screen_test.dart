import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/features/catalog/domain/product.dart';
import 'package:prueba01/features/catalog/domain/product_filters.dart';

import '../../support/catalog_test_support.dart';

void main() {
  CatalogFakeProductRepository repository() => CatalogFakeProductRepository(
    products: const [catalogGpu, catalogCpu, catalogPrebuilt],
  );

  testWidgets('prebuilt family hides part chips and lists only computers', (
    tester,
  ) async {
    final fake = repository();
    await pumpCatalogScreen(tester, fake);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ChoiceChip, 'GPU'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Computadores armados'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ChoiceChip, 'GPU'), findsNothing);
    expect(find.text(catalogPrebuilt.name), findsOneWidget);
    expect(find.text(catalogGpu.name), findsNothing);
    expect(fake.requests.last.filters.family, ProductFamily.prebuiltPc);
  });

  testWidgets('sort menu changes the order sent to the repository', (
    tester,
  ) async {
    final fake = repository();
    await pumpCatalogScreen(tester, fake);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Relevancia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Menor precio').last);
    await tester.pumpAndSettle();

    expect(fake.requests.last.filters.sort, ProductSort.priceAsc);
    expect(find.text('Menor precio'), findsOneWidget);
  });

  testWidgets('filters sheet applies brand and price and counts them', (
    tester,
  ) async {
    final fake = repository();
    await pumpCatalogScreen(tester, fake);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Filtros'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'AMD'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Hasta \$1.000.000'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('VER RESULTADOS'));
    await tester.pumpAndSettle();

    final filters = fake.requests.last.filters;
    expect(filters.brand, 'AMD');
    expect(filters.minPriceCents, isNull);
    expect(filters.maxPriceCents, 100000000);
    expect(find.text('Filtros (2)'), findsOneWidget);
    expect(find.text(catalogCpu.name), findsOneWidget);
    expect(find.text(catalogGpu.name), findsNothing);
  });

  testWidgets('header fits a 360 px phone with the longest labels', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpCatalogScreen(tester, repository());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Relevancia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mayor precio').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filtros'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'NVIDIA'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Más de \$6.000.000'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('VER RESULTADOS'));
    await tester.pumpAndSettle();

    expect(find.text('Mayor precio'), findsOneWidget);
    expect(find.text('Filtros (2)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail lists each provider offer', (tester) async {
    await pumpProductDetailScreen(
      tester,
      CatalogFakeProductRepository(products: const [catalogGpuWithOffers]),
      catalogGpuWithOffers.id,
    );
    await tester.pumpAndSettle();

    expect(find.text('OFERTAS DE PROVEEDORES'), findsOneWidget);
    expect(find.text('Proveedor A'), findsOneWidget);
    expect(find.text('Proveedor B'), findsOneWidget);
    expect(find.text('\$1.500'), findsOneWidget);
  });

  testWidgets('detail without offers omits the offers section', (tester) async {
    await pumpProductDetailScreen(
      tester,
      CatalogFakeProductRepository(products: const [catalogCpu]),
      catalogCpu.id,
    );
    await tester.pumpAndSettle();

    expect(find.text('OFERTAS DE PROVEEDORES'), findsNothing);
    expect(find.text('VENDIDO POR'), findsNothing);
  });
}
