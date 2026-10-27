import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/features/catalog/catalog_providers.dart';
import 'package:prueba01/features/catalog/domain/product.dart';
import 'package:prueba01/features/catalog/domain/product_filters.dart';
import 'package:prueba01/features/catalog/domain/product_page.dart';
import 'package:prueba01/features/catalog/domain/product_repository.dart';
import 'package:prueba01/features/catalog/presentation/catalog_screen.dart';
import 'package:prueba01/features/catalog/presentation/product_detail_screen.dart';
import 'package:prueba01/routes.dart';

const catalogGpu = Product(
  id: 'gpu-test',
  name: 'NVIDIA RTX TEST',
  brand: 'NVIDIA',
  category: ProductCategory.gpu,
  priceCents: 100000,
  stockLevel: StockLevel.stable,
);

const catalogCpu = Product(
  id: 'cpu-test',
  name: 'AMD CPU TEST',
  brand: 'AMD',
  category: ProductCategory.cpu,
  priceCents: 100000,
  stockLevel: StockLevel.stable,
);

const catalogRam = Product(
  id: 'ram-test',
  name: 'RAM TEST',
  brand: 'NEXUS',
  category: ProductCategory.ram,
  priceCents: 100000,
  stockLevel: StockLevel.stable,
);

const catalogStorage = Product(
  id: 'storage-test',
  name: 'STORAGE TEST',
  brand: 'NEXUS',
  category: ProductCategory.storage,
  priceCents: 100000,
  stockLevel: StockLevel.stable,
);

const catalogOutOfStock = Product(
  id: 'out-of-stock-test',
  name: 'OUT OF STOCK PRODUCT',
  brand: 'NEXUS',
  category: ProductCategory.cooling,
  priceCents: 100000,
  stockLevel: StockLevel.outOfStock,
  specs: [ProductSpec(label: 'MODEL', value: 'TEST')],
);

const catalogGpuWithOffers = Product(
  id: 'gpu-offers-test',
  name: 'GPU CON OFERTAS',
  brand: 'NVIDIA',
  category: ProductCategory.gpu,
  priceCents: 100000,
  stockLevel: StockLevel.stable,
  offers: [
    ProductOffer(
      id: 'offer-a',
      providerId: 'provider-a',
      providerName: 'Proveedor A',
      priceCents: 100000,
      stockLevel: StockLevel.stable,
    ),
    ProductOffer(
      id: 'offer-b',
      providerId: 'provider-b',
      providerName: 'Proveedor B',
      priceCents: 120000,
      oldPriceCents: 150000,
      stockLevel: StockLevel.critical,
    ),
  ],
);

typedef CatalogPageLoader = Future<ProductPage> Function(
  int page,
  int pageSize,
  ProductFilters filters,
);

typedef CatalogPageRequest = ({
  int page,
  int pageSize,
  String? search,
  ProductCategory? category,
  ProductFilters filters,
});

class CatalogFakeProductRepository implements ProductRepository {
  CatalogFakeProductRepository({
    this.products = const [catalogGpu, catalogCpu],
    this.pageCompleter,
    this.failFirstPageRequest = false,
    this.failProductLookup = false,
    this.pageLoader,
  });

  final List<Product> products;
  final Completer<ProductPage>? pageCompleter;
  final bool failFirstPageRequest;
  final bool failProductLookup;
  final CatalogPageLoader? pageLoader;
  final requests = <CatalogPageRequest>[];
  final brandRequests = <ProductCategory?>[];
  var productPageRequests = 0;

  @override
  Future<ProductPage> getProducts({
    int page = 0,
    int pageSize = 20,
    ProductFilters filters = const ProductFilters(),
  }) {
    productPageRequests++;
    requests.add((
      page: page,
      pageSize: pageSize,
      search: filters.search.isEmpty ? null : filters.search,
      category: filters.category,
      filters: filters,
    ));
    final loader = pageLoader;
    if (loader != null) return loader(page, pageSize, filters);
    if (pageCompleter != null) return pageCompleter!.future;
    if (failFirstPageRequest && productPageRequests == 1) {
      return Future.error(StateError('network error'));
    }

    final normalizedSearch = filters.search.toLowerCase().trim();
    final matches = products.where((product) {
      final matchesCategory =
          filters.category == null || product.category == filters.category;
      final matchesBrand =
          filters.brand == null || product.brand == filters.brand;
      final matchesSearch =
          normalizedSearch.isEmpty ||
          product.name.toLowerCase().contains(normalizedSearch) ||
          product.brand.toLowerCase().contains(normalizedSearch);
      return matchesCategory && matchesBrand && matchesSearch;
    }).toList();
    final start = page * pageSize;
    return Future.value(
      ProductPage(
        items: matches.skip(start).take(pageSize).toList(),
        total: matches.length,
        page: page,
        pageSize: pageSize,
      ),
    );
  }

  @override
  Future<Product?> getById(String id) async {
    if (failProductLookup) throw StateError('detail error');
    return products.where((product) => product.id == id).firstOrNull;
  }

  @override
  Future<List<Product>> getRelated(String id, {int limit = 2}) async =>
      products.where((product) => product.id != id).take(limit).toList();

  @override
  Future<List<String>> getBrands({ProductCategory? category}) async {
    brandRequests.add(category);
    return products
        .where((product) => category == null || product.category == category)
        .map((product) => product.brand)
        .toSet()
        .toList();
  }
}

CatalogFakeProductRepository createRetryablePageRepository() {
  var failedPageRequest = false;
  const products = [catalogGpu, catalogCpu, catalogRam, catalogStorage];
  return CatalogFakeProductRepository(
    products: products,
    pageLoader: (page, pageSize, filters) {
      if (page == 1 && !failedPageRequest) {
        failedPageRequest = true;
        return Future.error(StateError('page failure'));
      }
      final start = page * pageSize;
      return Future.value(
        ProductPage(
          items: products.skip(start).take(pageSize).toList(),
          total: products.length,
          page: page,
          pageSize: pageSize,
        ),
      );
    },
  );
}

CatalogFakeProductRepository createStaleCategoryRepository(
  Completer<ProductPage> gpuCompleter,
  Completer<ProductPage> cpuCompleter,
) => CatalogFakeProductRepository(
  pageLoader: (page, pageSize, filters) {
    if (filters.category == ProductCategory.gpu) return gpuCompleter.future;
    if (filters.category == ProductCategory.cpu) return cpuCompleter.future;
    return Future.value(
      const ProductPage(
        items: [catalogGpu, catalogCpu],
        total: 2,
        page: 0,
        pageSize: 20,
      ),
    );
  },
);

CatalogPageLoader createInitialRetryLoader() {
  var requestCount = 0;
  return (page, pageSize, filters) {
    requestCount++;
    if (requestCount == 1) return Future.error(StateError('temporary failure'));
    return Future.value(
      ProductPage(
        items: const [catalogGpu],
        total: 1,
        page: page,
        pageSize: pageSize,
      ),
    );
  };
}

ProviderContainer createCatalogContainer(
  CatalogFakeProductRepository repository, {
  int pageSize = 20,
}) => ProviderContainer(
  overrides: [
    productRepositoryProvider.overrideWithValue(repository),
    catalogPageSizeProvider.overrideWithValue(pageSize),
  ],
  retry: (retryCount, error) => null,
);

class CatalogControllerHarness {
  CatalogControllerHarness({
    required this.repository,
    int pageSize = 20,
  }) : container = createCatalogContainer(repository, pageSize: pageSize);

  final CatalogFakeProductRepository repository;
  final ProviderContainer container;

  CatalogController get controller =>
      container.read(catalogControllerProvider.notifier);

  CatalogState get state => container.read(catalogControllerProvider).requireValue;

  Future<CatalogState> load() =>
      container.read(catalogControllerProvider.future);

  void dispose() => container.dispose();
}

List<Product> generateCatalogProducts(int count) => List<Product>.generate(
  count,
  (index) => Product(
    id: 'product-${index + 1}',
    name: 'Product ${index + 1}',
    brand: 'Brand',
    category: ProductCategory.gpu,
    priceCents: 100000,
    stockLevel: StockLevel.stable,
  ),
);

Widget catalogTestApp(
  ProductRepository repository, {
  int pageSize = 20,
}) => ProviderScope(
  overrides: [
    productRepositoryProvider.overrideWithValue(repository),
    catalogPageSizeProvider.overrideWithValue(pageSize),
  ],
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

Widget productDetailTestApp(
  ProductRepository repository,
  String productId,
) => ProviderScope(
  overrides: [productRepositoryProvider.overrideWithValue(repository)],
  retry: (retryCount, error) => null,
  child: MaterialApp(
    home: ProductDetailScreen(productId: productId),
  ),
);

Future<void> pumpCatalogScreen(
  WidgetTester tester,
  ProductRepository repository, {
  int pageSize = 20,
}) async {
  await tester.pumpWidget(catalogTestApp(repository, pageSize: pageSize));
}

Future<void> pumpProductDetailScreen(
  WidgetTester tester,
  ProductRepository repository,
  String productId,
) async {
  await tester.pumpWidget(productDetailTestApp(repository, productId));
}
