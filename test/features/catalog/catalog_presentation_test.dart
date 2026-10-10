import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/features/catalog/catalog_providers.dart';
import 'package:prueba01/features/catalog/domain/product.dart';
import 'package:prueba01/features/catalog/domain/product_page.dart';
import 'package:prueba01/features/catalog/domain/product_repository.dart';
import 'package:prueba01/features/catalog/presentation/catalog_screen.dart';
import 'package:prueba01/features/catalog/presentation/product_detail_screen.dart';
import 'package:prueba01/routes.dart';
import 'package:prueba01/widgets/nexus_error_state.dart';
import 'package:prueba01/widgets/nexus_product_card.dart';

const _gpu = Product(
  id: 'gpu-test',
  name: 'NVIDIA GEFORCE RTX 5080',
  brand: 'NVIDIA',
  category: ProductCategory.gpu,
  priceCents: 169900,
  stockLevel: StockLevel.stable,
);

const _cpu = Product(
  id: 'cpu-test',
  name: 'RYZEN TEST CPU',
  brand: 'AMD',
  category: ProductCategory.cpu,
  priceCents: 64900,
  stockLevel: StockLevel.stable,
);

class _FakeProductRepository implements ProductRepository {
  _FakeProductRepository({
    this.products = const [_gpu, _cpu],
    this.pageCompleter,
    this.failFirstPageRequest = false,
    this.failProductLookup = false,
  });

  final List<Product> products;
  final Completer<ProductPage>? pageCompleter;
  final bool failFirstPageRequest;
  final bool failProductLookup;
  var productPageRequests = 0;

  @override
  Future<ProductPage> getProducts({
    int page = 0,
    int pageSize = 20,
    String? search,
    ProductCategory? category,
  }) {
    productPageRequests++;
    if (pageCompleter != null) return pageCompleter!.future;
    if (failFirstPageRequest && productPageRequests == 1) {
      return Future.error(StateError('network error'));
    }
    return Future.value(
      ProductPage(
        items: products,
        total: products.length,
        page: page,
        pageSize: pageSize,
      ),
    );
  }

  @override
  Future<Product?> getById(String id) async {
    if (failProductLookup) throw StateError('detail error');
    for (final product in products) {
      if (product.id == id) return product;
    }
    return null;
  }

  @override
  Future<List<Product>> getRelated(String id, {int limit = 2}) async =>
      products.where((product) => product.id != id).take(limit).toList();
}

Widget _catalogApp(_FakeProductRepository repository) => ProviderScope(
  overrides: [productRepositoryProvider.overrideWithValue(repository)],
  retry: (retryCount, error) => null,
  child: MaterialApp(
    home: const CatalogScreen(),
    onGenerateRoute: (settings) {
      if (settings.name != NexusRoutes.productDetail) return null;
      final productId = settings.arguments;
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => ProductDetailScreen(
          productId: productId is String ? productId : '',
        ),
      );
    },
  ),
);

void main() {
  test(
    'detail provider reads a product from the overridden repository',
    () async {
      final container = ProviderContainer(
        overrides: [
          productRepositoryProvider.overrideWithValue(_FakeProductRepository()),
        ],
        retry: (retryCount, error) => null,
      );
      addTearDown(container.dispose);

      final product = await container.read(
        productDetailProvider(_gpu.id).future,
      );

      expect(product?.id, _gpu.id);
    },
  );

  test(
    'detail provider exposes repository failures without retrying',
    () async {
      final container = ProviderContainer(
        overrides: [
          productRepositoryProvider.overrideWithValue(
            _FakeProductRepository(failProductLookup: true),
          ),
        ],
        retry: (retryCount, error) => null,
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(productDetailProvider(_gpu.id).future),
        throwsA(isA<StateError>()),
      );
    },
  );

  testWidgets('catalog shows loading then products from its repository', (
    WidgetTester tester,
  ) async {
    final pageCompleter = Completer<ProductPage>();
    final repository = _FakeProductRepository(pageCompleter: pageCompleter);
    await tester.pumpWidget(_catalogApp(repository));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pageCompleter.complete(
      const ProductPage(items: [_gpu, _cpu], total: 2, page: 0, pageSize: 20),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('2 productos'), findsOneWidget);
    expect(find.text(_gpu.name), findsOneWidget);
    expect(find.text(_cpu.name), findsOneWidget);
  });

  testWidgets('catalog error can be retried', (WidgetTester tester) async {
    final repository = _FakeProductRepository(failFirstPageRequest: true);
    await tester.pumpWidget(_catalogApp(repository));
    await tester.pump();
    await tester.pump();

    expect(find.byType(NexusErrorState), findsOneWidget);
    expect(find.textContaining('network error'), findsOneWidget);

    await tester.tap(find.text('REINTENTAR'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(repository.productPageRequests, 2);
    expect(find.text(_gpu.name), findsOneWidget);
  });

  testWidgets('each catalog card opens its own product detail', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_catalogApp(_FakeProductRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text(_cpu.name));
    await tester.pumpAndSettle();

    expect(find.byType(NexusProductCard), findsWidgets);
    expect(find.text(_cpu.name), findsOneWidget);
    expect(find.text('AMD'), findsOneWidget);
  });

  testWidgets('detail reports an unknown product id', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productRepositoryProvider.overrideWithValue(_FakeProductRepository()),
        ],
        retry: (retryCount, error) => null,
        child: const MaterialApp(
          home: ProductDetailScreen(productId: 'missing'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Producto no encontrado'), findsOneWidget);
  });

  testWidgets('detail omits empty specification sections', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productRepositoryProvider.overrideWithValue(
            _FakeProductRepository(products: const [_cpu]),
          ),
        ],
        retry: (retryCount, error) => null,
        child: const MaterialApp(
          home: ProductDetailScreen(productId: 'cpu-test'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SPECS RÁPIDAS'), findsNothing);
    expect(find.text('ESPECIFICACIONES COMPLETAS'), findsNothing);
  });
}
