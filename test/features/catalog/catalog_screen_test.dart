import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/features/catalog/domain/product_page.dart';
import 'package:prueba01/features/catalog/data/mock_product_repository.dart';
import 'package:prueba01/theme/nexus_theme.dart';
import 'package:prueba01/widgets/nexus_error_state.dart';
import 'package:prueba01/widgets/nexus_product_card.dart';
import 'package:prueba01/widgets/nexus_widgets.dart';

import '../../support/catalog_test_support.dart';

void main() {
  testWidgets('catalog loads products from its repository', (tester) async {
    final completer = Completer<ProductPage>();
    await pumpCatalogScreen(
      tester,
      CatalogFakeProductRepository(pageCompleter: completer),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(
      const ProductPage(
        items: [catalogGpu, catalogCpu],
        total: 2,
        page: 0,
        pageSize: 20,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 productos'), findsOneWidget);
    expect(find.text(catalogGpu.name), findsOneWidget);
    expect(find.text(catalogCpu.name), findsOneWidget);
  });

  testWidgets('catalog error state retries its request', (tester) async {
    final repository = CatalogFakeProductRepository(failFirstPageRequest: true);
    await pumpCatalogScreen(tester, repository);
    await tester.pumpAndSettle();
    expect(find.byType(NexusErrorState), findsOneWidget);
    expect(find.textContaining('network error'), findsOneWidget);

    await tester.tap(find.text('REINTENTAR'));
    await tester.pumpAndSettle();
    expect(repository.productPageRequests, 2);
    expect(find.text(catalogGpu.name), findsOneWidget);
  });

  testWidgets('catalog card opens the selected product detail', (tester) async {
    await pumpCatalogScreen(tester, CatalogFakeProductRepository());
    await tester.pumpAndSettle();
    await tester.tap(find.text(catalogCpu.name));
    await tester.pumpAndSettle();

    expect(find.byType(NexusProductCard), findsWidgets);
    expect(find.text('AMD'), findsOneWidget);
  });

  testWidgets('catalog card shows out-of-stock status in faint gray', (
    tester,
  ) async {
    await pumpCatalogScreen(
      tester,
      CatalogFakeProductRepository(products: const [catalogOutOfStock]),
    );
    await tester.pumpAndSettle();

    final status = tester.widget<NexusStatusDot>(
      find.byWidgetPredicate(
        (widget) => widget is NexusStatusDot && widget.label == 'AGOTADO',
      ),
    );
    expect(status.color, NexusColors.textFaint);
  });

  testWidgets('search filters products after the debounce', (tester) async {
    await pumpCatalogScreen(tester, CatalogFakeProductRepository());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'NVIDIA');
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pumpAndSettle();

    expect(find.text(catalogGpu.name), findsOneWidget);
    expect(find.text(catalogCpu.name), findsNothing);
  });

  testWidgets('selecting a category chip filters the catalog', (tester) async {
    await pumpCatalogScreen(tester, CatalogFakeProductRepository());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'GPU'));
    await tester.pumpAndSettle();

    expect(find.text(catalogGpu.name), findsOneWidget);
    expect(find.text(catalogCpu.name), findsNothing);
  });

  testWidgets('tapping the selected category chip clears its filter', (
    tester,
  ) async {
    await pumpCatalogScreen(tester, CatalogFakeProductRepository());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'GPU'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'GPU'));
    await tester.pumpAndSettle();

    expect(find.text(catalogGpu.name), findsOneWidget);
    expect(find.text(catalogCpu.name), findsOneWidget);
  });

  testWidgets('scrolling near the end requests the next page', (tester) async {
    final repository = CatalogFakeProductRepository(
      products: generateCatalogProducts(4),
    );
    await pumpCatalogScreen(tester, repository, pageSize: 2);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
    await tester.pumpAndSettle();

    expect(repository.requests.map((request) => request.page), [0, 1]);
    expect(find.text('Product 4'), findsOneWidget);
  });

  testWidgets('empty results can clear active filters', (tester) async {
    await pumpCatalogScreen(tester, CatalogFakeProductRepository());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'missing product');
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Limpiar filtros'));
    await tester.pumpAndSettle();

    expect(find.text(catalogGpu.name), findsOneWidget);
    expect(find.text('missing product'), findsNothing);
  });

  testWidgets('results header displays the repository total', (tester) async {
    await pumpCatalogScreen(
      tester,
      CatalogFakeProductRepository(products: generateCatalogProducts(4)),
      pageSize: 1,
    );
    await tester.pumpAndSettle();

    expect(find.text('4 productos'), findsOneWidget);
  });

  testWidgets('Kraken card labels out-of-stock inventory as AGOTADO', (
    tester,
  ) async {
    await pumpCatalogScreen(
      tester,
      MockProductRepository(latency: Duration.zero),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
    await tester.pumpAndSettle();

    expect(find.text('KRAKEN ELITE 360'), findsOneWidget);
    expect(find.text('AGOTADO'), findsOneWidget);
  });
}
