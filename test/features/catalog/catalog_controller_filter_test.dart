import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/features/catalog/domain/product.dart';
import '../../support/catalog_test_support.dart';

void main() {
  test('filters catalog by selected category', () async {
    final harness = CatalogControllerHarness(
      repository: CatalogFakeProductRepository(),
    );
    addTearDown(harness.dispose);
    await harness.load();

    await harness.controller.setCategory(ProductCategory.gpu);
    expect(harness.state.productIds, [catalogGpu.id]);
    expect(harness.state.category, ProductCategory.gpu);
  });

  test('clear filters restores all catalog products', () async {
    final harness = CatalogControllerHarness(
      repository: CatalogFakeProductRepository(),
    );
    addTearDown(harness.dispose);
    await harness.load();
    await harness.controller.setCategory(ProductCategory.gpu);

    await harness.controller.clearFilters();
    expect(harness.state.productIds, [catalogGpu.id, catalogCpu.id]);
    expect(harness.state.query, isEmpty);
    expect(harness.state.category, isNull);
  });
}
