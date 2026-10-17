import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/features/catalog/domain/product.dart';
import 'package:prueba01/features/catalog/domain/product_page.dart';
import '../../support/catalog_test_support.dart';

void main() {
  test('ignores a stale category response', () async {
    final gpuCompleter = Completer<ProductPage>();
    final cpuCompleter = Completer<ProductPage>();
    final harness = CatalogControllerHarness(
      repository: createStaleCategoryRepository(gpuCompleter, cpuCompleter),
    );
    addTearDown(harness.dispose);
    await harness.load();

    final stale = harness.controller.setCategory(ProductCategory.gpu);
    final latest = harness.controller.setCategory(ProductCategory.cpu);
    cpuCompleter.complete(const ProductPage(items: [catalogCpu], total: 1, page: 0, pageSize: 20));
    await latest;
    gpuCompleter.complete(const ProductPage(items: [catalogGpu], total: 1, page: 0, pageSize: 20));
    await stale;

    expect(harness.state.category, ProductCategory.cpu);
    expect(harness.state.items, [catalogCpu]);
  });

  test('retry reloads catalog after initial repository failure', () async {
    final repository = CatalogFakeProductRepository(
      pageLoader: createInitialRetryLoader(),
    );
    final harness = CatalogControllerHarness(repository: repository);
    addTearDown(harness.dispose);

    await expectLater(harness.load(), throwsA(isA<StateError>()));
    await harness.controller.retry();
    expect(harness.state.items, [catalogGpu]);
    expect(repository.requests, hasLength(2));
  });
}
