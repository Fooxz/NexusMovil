import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/features/catalog/domain/product.dart';
import '../../support/catalog_test_support.dart';

void main() {
  test('debounces search and requests only the latest query', () async {
    final harness = CatalogControllerHarness(
      repository: CatalogFakeProductRepository(),
    );
    addTearDown(harness.dispose);
    await harness.load();

    await harness.controller.setSearch('NVIDIA');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await harness.controller.setSearch('AMD');
    await Future<void>.delayed(const Duration(milliseconds: 350));

    expect(harness.state.query, 'AMD');
    expect(harness.state.productIds, [catalogCpu.id]);
    expect(harness.repository.requests.last.search, 'AMD');
  });

  test('cancels pending search when input returns to active query', () async {
    final harness = CatalogControllerHarness(
      repository: CatalogFakeProductRepository(),
    );
    addTearDown(harness.dispose);
    await harness.load();

    await harness.controller.setSearch('NVIDIA');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await harness.controller.setSearch('');
    await Future<void>.delayed(const Duration(milliseconds: 350));

    expect(harness.repository.requests, hasLength(1));
    expect(harness.state.query, isEmpty);
  });

  test('search debounce uses the latest selected category', () async {
    final harness = CatalogControllerHarness(
      repository: CatalogFakeProductRepository(),
    );
    addTearDown(harness.dispose);
    await harness.load();

    await harness.controller.setSearch('AMD');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await harness.controller.setCategory(ProductCategory.cpu);
    await Future<void>.delayed(const Duration(milliseconds: 350));

    expect(harness.state.query, 'AMD');
    expect(harness.state.category, ProductCategory.cpu);
    expect(harness.state.productIds, [catalogCpu.id]);
  });
}
