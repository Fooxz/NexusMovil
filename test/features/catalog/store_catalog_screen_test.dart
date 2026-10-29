import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/features/catalog/catalog_providers.dart';
import 'package:prueba01/features/catalog/data/mock_product_repository.dart';
import 'package:prueba01/features/catalog/domain/product_filters.dart';
import 'package:prueba01/features/catalog/presentation/catalog_offer_card.dart';
import 'package:prueba01/features/catalog/presentation/product_detail_screen.dart';
import 'package:prueba01/features/catalog/presentation/store_catalog_screen.dart';
import 'package:prueba01/main.dart';

import '../../support/auth_test_support.dart' show tapAndSettle, usePhoneViewport;

void main() {
  late MockProductRepository repository;

  setUp(() => repository = MockProductRepository(latency: Duration.zero));

  Future<void> pumpDetail(WidgetTester tester, String productId) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [productRepositoryProvider.overrideWithValue(repository)],
        retry: (retryCount, error) => null,
        child: MaterialApp(
          onGenerateRoute: generateNexusRoute,
          home: ProductDetailScreen(productId: productId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('el detalle muestra quién vende y abre el catálogo de esa tienda', (tester) async {
    final product = (await tester.runAsync(() => repository.getById('rtx-5090')))!;
    final seller = product.offers.firstWhere((offer) => offer.id == product.bestOfferId);
    await pumpDetail(tester, product.id);

    expect(find.text('VENDIDO POR'), findsOneWidget);
    expect(find.text(seller.providerName), findsWidgets);
    await tapAndSettle(tester, find.text('Ver tienda'));

    expect(find.byType(StoreCatalogScreen), findsOneWidget);
    expect(find.text('TIENDA'), findsOneWidget);
    final storeOffers = (await tester.runAsync(
      () => repository.getOffers(pageSize: 50, filters: _filtersFor(seller.providerId)),
    ))!;
    final count = storeOffers.total == 1 ? '1 pieza' : '${storeOffers.total} piezas';
    expect(find.textContaining(count), findsOneWidget);
    // Solo las piezas de esa tienda, sin repetir su nombre en cada tarjeta.
    for (final card in tester.widgetList<CatalogOfferCard>(find.byType(CatalogOfferCard))) {
      expect(card.offer.providerId, seller.providerId);
      expect(card.showSeller, isFalse);
    }
  });

  testWidgets('el catálogo de la tienda filtra por tipo de pieza', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [productRepositoryProvider.overrideWithValue(repository)],
        retry: (retryCount, error) => null,
        child: const MaterialApp(home: StoreCatalogScreen(storeId: 'prov-tecnopartes', storeName: 'TecnoPartes')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TecnoPartes'), findsOneWidget);
    await tapAndSettle(tester, find.widgetWithText(ChoiceChip, 'GPU'));
    final cards = tester.widgetList<CatalogOfferCard>(find.byType(CatalogOfferCard)).toList();
    expect(cards, isNotEmpty);
    expect(cards.every((card) => card.offer.providerId == 'prov-tecnopartes'), isTrue);
    expect(cards.every((card) => card.offer.category.name == 'gpu'), isTrue);
  });
}

ProductFilters _filtersFor(String providerId) => ProductFilters(providerId: providerId);
