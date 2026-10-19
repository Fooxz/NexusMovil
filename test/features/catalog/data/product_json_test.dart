import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/features/catalog/data/product_json.dart';
import 'package:prueba01/features/catalog/domain/product.dart';

import '../../../support/contract_fixtures.dart';

void main() {
  test('reads the shared listing fixture of the contract', () {
    final page = productPageFromJson(contractListingFixture);

    expect(page.total, 2);
    expect(page.pageSize, 20);
    expect(page.hasMore, isFalse);
    expect(page.items.map((product) => product.id), [
      'gpu-rtx-5090',
      'cpu-ryzen-9-9950x',
    ]);

    final gpu = page.items.first;
    expect(gpu.family, ProductFamily.part);
    expect(gpu.category, ProductCategory.gpu);
    expect(gpu.priceCents, 799600000);
    expect(gpu.oldPriceCents, 919600000);
    expect(gpu.discountPercent, 13);
    expect(gpu.imageUrl, startsWith('https://'));
    expect(gpu.specs.first.label, 'VRAM');
    expect(gpu.offers, isEmpty);
    expect(gpu.bestOfferId, 'off-1001');

    final cpu = page.items.last;
    expect(cpu.imageUrl, isNull);
    expect(cpu.quickSpecs, isEmpty);
  });

  test('reads offers in the product detail', () {
    final product = productFromJson(contractDetailFixture)!;

    expect(product.offers, hasLength(1));
    final offer = product.offers.single;
    expect(offer.providerName, 'TecnoPartes SAS');
    expect(offer.priceCents, 799600000);
    expect(offer.hasDiscount, isTrue);
    expect(offer.stockLevel, StockLevel.stable);
  });

  test('reads prebuilt computers', () {
    final product = productFromJson({
      ...contractDetailFixture,
      'family': 'prebuiltPc',
      'category': 'prebuiltPc',
    })!;

    expect(product.family, ProductFamily.prebuiltPc);
  });

  test('ignores unknown fields and treats unknown stock as out of stock', () {
    final product = productFromJson({
      ...contractDetailFixture,
      'stockLevel': 'backorder',
      'newField': {'nested': true},
    })!;

    expect(product.stockLevel, StockLevel.outOfStock);
  });

  test('skips products of unknown categories in lists', () {
    final products = productListFromJson([
      contractDetailFixture,
      {...contractDetailFixture, 'id': 'phone-1', 'category': 'phone'},
    ]);

    expect(products.map((product) => product.id), ['gpu-rtx-5090']);
  });

  test('rejects products without required fields or with wrong types', () {
    expect(
      () => productFromJson({...contractDetailFixture}..remove('priceCents')),
      throwsFormatException,
    );
    expect(
      () => productFromJson({...contractDetailFixture, 'priceCents': '100'}),
      throwsFormatException,
    );
    expect(
      () => productFromJson({...contractDetailFixture, 'imageUrl': 42}),
      throwsFormatException,
    );
    expect(() => productPageFromJson({'items': []}), throwsFormatException);
  });
}
