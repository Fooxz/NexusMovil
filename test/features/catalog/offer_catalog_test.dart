import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/features/auth/auth_providers.dart';
import 'package:prueba01/features/auth/data/mock_auth_repository.dart';
import 'package:prueba01/features/cart/cart_providers.dart';
import 'package:prueba01/features/catalog/catalog_providers.dart';
import 'package:prueba01/features/catalog/data/mock_product_repository.dart';
import 'package:prueba01/features/catalog/data/product_json.dart';
import 'package:prueba01/features/catalog/data/supabase_product_repository.dart';
import 'package:prueba01/features/catalog/domain/product.dart';
import 'package:prueba01/features/catalog/domain/product_filters.dart';
import 'package:prueba01/features/catalog/presentation/catalog_screen.dart';
import 'package:prueba01/main.dart';
import 'package:prueba01/widgets/nexus_product_card.dart';

import '../../support/account_test_support.dart';

const _offerJson = {
  'offerId': 'off-b',
  'productId': 'rtx-5070',
  'name': 'NVIDIA RTX 5070',
  'brand': 'NVIDIA',
  'category': 'gpu',
  'providerId': 'prov-b',
  'providerName': 'Tienda B',
  'priceCents': 265000000,
  'oldPriceCents': 280000000,
  'stockLevel': 'critical',
  'imageUrl': null,
  'summary': '12 GB GDDR7',
  'quickSpecs': ['12GB'],
  'offerCount': 3,
};

/// Catálogo con los mocks reales (la RTX 5090 la venden TecnoPartes y Mundo
/// PC) y el carrito de invitado.
Widget _catalogApp({List<dynamic> extraOverrides = const []}) => ProviderScope(
  overrides: [
    productRepositoryProvider.overrideWithValue(MockProductRepository(latency: Duration.zero)),
    authRepositoryProvider.overrideWithValue(MockAuthRepository(latency: Duration.zero)),
    ...extraOverrides.cast(),
  ],
  retry: (retryCount, error) => null,
  child: const MaterialApp(home: CatalogScreen(), onGenerateRoute: generateNexusRoute),
);

Finder _cardOf(String store) => find.ancestor(
  of: find.text(store),
  matching: find.byType(NexusProductCard),
);

void main() {
  group('JSON del catálogo por oferta (API_CONTRATO parte 6)', () {
    test('lee una tarjeta con su tienda, su precio y cuántas tiendas venden', () {
      final page = offerPageFromJson({
        'items': [
          _offerJson,
          {..._offerJson, 'offerId': 'off-x', 'category': 'phone'},
        ],
        'total': 2,
        'page': 0,
        'pageSize': 20,
      });

      final offer = page.items.single;
      expect(offer.offerId, 'off-b');
      expect(offer.providerName, 'Tienda B');
      expect(offer.priceCents, 265000000);
      expect(offer.discountPercent, 5);
      expect(offer.stockLevel, StockLevel.critical);
      expect(offer.offerCount, 3);
      expect(page.total, 2, reason: 'una categoría desconocida se omite, el total es el del backend');
    });

    test('falla si falta la tienda', () {
      expect(
        () => catalogOfferFromJson({..._offerJson}..remove('providerName')),
        throwsFormatException,
      );
    });

    test('lee las tiendas del filtro', () {
      final stores = catalogStoresFromJson([
        {'id': 'prov-a', 'displayName': 'Tienda A', 'offerCount': 4},
      ]);
      expect(stores.single.id, 'prov-a');
      expect(stores.single.offerCount, 4);
    });
  });

  test('el repositorio de Supabase envía el filtro por tienda a get_offers', () async {
    final calls = <(String, Map<String, Object?>)>[];
    final repository = SupabaseProductRepository((function, params) async {
      calls.add((function, params));
      return function == 'get_offers'
          ? {'items': [_offerJson], 'total': 1, 'page': 0, 'pageSize': 20}
          : [
              {'id': 'prov-b', 'displayName': 'Tienda B', 'offerCount': 1},
            ];
    });

    await repository.getOffers(
      filters: const ProductFilters(
        search: 'rtx',
        category: ProductCategory.gpu,
        providerId: 'prov-b',
        sort: ProductSort.priceAsc,
      ),
    );
    await repository.getStores(category: ProductCategory.gpu);

    expect(calls[0].$1, 'get_offers');
    expect(calls[0].$2, {
      'page': 0,
      'page_size': 20,
      'search': 'rtx',
      'category': 'gpu',
      'provider': 'prov-b',
      'sort': 'priceAsc',
    });
    expect(calls[1].$1, 'get_catalog_providers');
    expect(calls[1].$2, {'category': 'gpu'});
  });

  group('MockProductRepository.getOffers', () {
    final repository = MockProductRepository(latency: Duration.zero);

    test('una tarjeta por tienda, cada una con su precio', () async {
      final page = await repository.getOffers(filters: const ProductFilters(search: 'rtx 5090'));
      final rtx = page.items.where((offer) => offer.productId == 'rtx-5090').toList();

      expect(rtx.map((offer) => offer.providerName), ['TecnoPartes', 'Mundo PC']);
      expect(rtx.map((offer) => offer.priceCents), [799600000, 815000000]);
      expect(rtx.map((offer) => offer.offerCount), [2, 2]);
    });

    test('filtra por tienda, busca por tienda y usa el precio de cada oferta', () async {
      final byStore = await repository.getOffers(filters: const ProductFilters(providerId: 'prov-mundopc'));
      expect(byStore.items.map((offer) => offer.offerId), ['off-mp-rtx5090']);

      final bySearch = await repository.getOffers(filters: const ProductFilters(search: 'mundo pc'));
      expect(bySearch.items.map((offer) => offer.providerName).toSet(), {'Mundo PC'});

      final cheap = await repository.getOffers(
        filters: const ProductFilters(search: 'rtx 5090', maxPriceCents: 800000000),
      );
      expect(cheap.items.map((offer) => offer.offerId), contains('off-tp-rtx5090'));
      expect(cheap.items.map((offer) => offer.offerId), isNot(contains('off-mp-rtx5090')));
    });

    test('lista las tiendas para el filtro', () async {
      final stores = await repository.getStores(category: ProductCategory.gpu);
      expect(stores.map((store) => store.displayName), containsAll(['TecnoPartes', 'Mundo PC']));
    });
  });

  group('pantalla del catálogo', () {
    testWidgets('el mismo producto aparece una vez por tienda', (tester) async {
      await tester.pumpWidget(_catalogApp());
      await tester.pumpAndSettle();

      expect(find.text('NVIDIA GEFORCE RTX 5090'), findsNWidgets(2));
      expect(_cardOf('TecnoPartes'), findsOneWidget);
      expect(_cardOf('Mundo PC'), findsOneWidget);
      expect(find.descendant(of: _cardOf('Mundo PC'), matching: find.text('\$8.150.000')), findsOneWidget);
      expect(find.descendant(of: _cardOf('TecnoPartes'), matching: find.text('\$7.996.000')), findsOneWidget);
      expect(find.descendant(of: _cardOf('Mundo PC'), matching: find.text('Comparar 2')), findsOneWidget);
    });

    testWidgets('"Agregar" lleva al carrito la oferta de esa tarjeta', (tester) async {
      await tester.pumpWidget(_catalogApp());
      await tester.pumpAndSettle();

      await tester.tap(find.descendant(of: _cardOf('Mundo PC'), matching: find.byIcon(Icons.shopping_cart)));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(tester.element(find.byType(CatalogScreen)));
      expect(container.read(guestCartProvider).map((entry) => entry.offerId), ['off-mp-rtx5090']);
    });

    testWidgets('el filtro por tienda deja solo sus tarjetas', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_catalogApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Filtros'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Mundo PC'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('VER RESULTADOS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('VER RESULTADOS'));
      await tester.pumpAndSettle();

      expect(find.text('1 resultado'), findsOneWidget);
      expect(_cardOf('Mundo PC'), findsOneWidget);
      expect(_cardOf('TecnoPartes'), findsNothing);
      expect(find.text('Filtros (1)'), findsOneWidget);
    });

    testWidgets('el detalle abre con la tienda de la tarjeta', (tester) async {
      await tester.pumpWidget(_catalogApp());
      await tester.pumpAndSettle();

      await tester.tap(find.descendant(of: _cardOf('Mundo PC'), matching: find.text('Ver')));
      await tester.pumpAndSettle();

      expect(find.text('COMPARAR TIENDAS'), findsOneWidget);
      // El encabezado muestra el precio de Mundo PC (y su fila también).
      expect(find.text('\$8.150.000'), findsNWidgets(2));
      expect(find.text('\$7.996.000'), findsOneWidget);
    });
  });

  group('cuentas que no compran', () {
    testWidgets('una tienda ve las tarjetas sin botón de carrito y el detalle sin compra', (tester) async {
      final bed = RoleTestBed();
      await bed.store();
      await tester.pumpWidget(
        ProviderScope(
          overrides: bed.overrides,
          retry: (retryCount, error) => null,
          child: const MaterialApp(home: CatalogScreen(), onGenerateRoute: generateNexusRoute),
        ),
      );
      await tester.pumpAndSettle();

      expect(_cardOf('Mundo PC'), findsOneWidget);
      expect(find.byIcon(Icons.shopping_cart), findsNothing);

      await tester.tap(find.descendant(of: _cardOf('Mundo PC'), matching: find.text('Ver')));
      await tester.pumpAndSettle();
      expect(find.text('COMPARAR TIENDAS'), findsOneWidget);
      expect(find.text('AGREGAR AL CARRITO'), findsNothing);
      expect(find.text('Las cuentas de tienda y de administración no compran en NEXUS.'), findsOneWidget);
    });
  });
}
