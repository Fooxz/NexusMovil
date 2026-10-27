import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/features/catalog/domain/product.dart';
import 'package:prueba01/features/catalog/domain/product_filters.dart';

import '../../support/catalog_test_support.dart';

void main() {
  late CatalogControllerHarness harness;

  setUp(() async {
    harness = CatalogControllerHarness(
      repository: CatalogFakeProductRepository(
        products: const [catalogGpu, catalogCpu, catalogRam],
      ),
    );
    await harness.load();
  });

  tearDown(() => harness.dispose());

  ProductFilters lastFilters() => harness.repository.requests.last.filters;

  test('a category filters the parts and drops the brand', () async {
    await harness.controller.setBrand('NVIDIA');
    await harness.controller.setCategory(ProductCategory.gpu);

    expect(lastFilters().category, ProductCategory.gpu);
    expect(lastFilters().brand, isNull);
    expect(harness.state.items, [catalogGpu]);
  });

  test('choosing "Todo" drops the category', () async {
    await harness.controller.setCategory(ProductCategory.cpu);

    await harness.controller.setCategory(null);

    expect(harness.state.category, isNull);
    expect(harness.state.items, hasLength(3));
  });

  test('sends brand, price range and sort to the repository', () async {
    await harness.controller.setBrand('AMD');
    await harness.controller.setPriceRange(
      minPriceCents: 100000,
      maxPriceCents: 300000000,
    );
    await harness.controller.setSort(ProductSort.priceDesc);

    expect(lastFilters().brand, 'AMD');
    expect(lastFilters().minPriceCents, 100000);
    expect(lastFilters().maxPriceCents, 300000000);
    expect(lastFilters().sort, ProductSort.priceDesc);
    expect(harness.state.page, 0);
  });

  test('clearing filters keeps the chosen sort', () async {
    await harness.controller.setSort(ProductSort.priceAsc);
    await harness.controller.setBrand('AMD');

    await harness.controller.clearFilters();

    expect(lastFilters(), const ProductFilters(sort: ProductSort.priceAsc));
  });

  test('repeating the same filter does not request again', () async {
    await harness.controller.setCategory(ProductCategory.ram);
    final requestCount = harness.repository.requests.length;

    await harness.controller.setCategory(ProductCategory.ram);
    await harness.controller.setSort(ProductSort.relevance);
    await harness.controller.setBrand(null);

    expect(harness.repository.requests, hasLength(requestCount));
  });
}
