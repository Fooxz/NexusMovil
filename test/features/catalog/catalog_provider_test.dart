import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/features/catalog/catalog_providers.dart';
import '../../support/catalog_test_support.dart';

void main() {
  test('detail provider reads a product from its repository', () async {
    final container = createCatalogContainer(CatalogFakeProductRepository());
    addTearDown(container.dispose);

    final product = await container.read(
      productDetailProvider(catalogGpu.id).future,
    );
    expect(product?.id, catalogGpu.id);
  });

  test('detail provider exposes repository failures', () async {
    final container = createCatalogContainer(
      CatalogFakeProductRepository(failProductLookup: true),
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(productDetailProvider(catalogGpu.id).future),
      throwsA(isA<StateError>()),
    );
  });
}
