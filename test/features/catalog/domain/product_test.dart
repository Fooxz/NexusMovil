import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/features/catalog/domain/product.dart';
import 'package:prueba01/features/catalog/domain/product_page.dart';

void main() {
  test('derives a rounded discount from the prices', () {
    const product = Product(
      id: 'discounted',
      name: 'Discounted product',
      brand: 'Brand',
      category: ProductCategory.gpu,
      priceCents: 199900,
      oldPriceCents: 229900,
      stockLevel: StockLevel.stable,
    );

    expect(product.hasDiscount, isTrue);
    expect(product.discountPercent, 13);
  });

  test('does not report a discount without an old price', () {
    const product = Product(
      id: 'regular',
      name: 'Regular product',
      brand: 'Brand',
      category: ProductCategory.cpu,
      priceCents: 10000,
      stockLevel: StockLevel.stable,
    );

    expect(product.hasDiscount, isFalse);
    expect(product.discountPercent, 0);
  });

  test('reports whether another product page exists', () {
    const firstPage = ProductPage(
      items: [],
      total: 3,
      page: 0,
      pageSize: 2,
    );
    const lastPage = ProductPage(
      items: [],
      total: 3,
      page: 1,
      pageSize: 2,
    );

    expect(firstPage.hasMore, isTrue);
    expect(lastPage.hasMore, isFalse);
  });

  test('maps stock levels to their catalog and detail labels', () {
    expect(StockLevel.stable.tagLabel, 'ESTABLE');
    expect(StockLevel.stable.detailLabel, 'EN STOCK');
    expect(StockLevel.critical.tagLabel, 'CRÍTICO');
    expect(StockLevel.critical.detailLabel, 'EN STOCK');
    expect(StockLevel.outOfStock.tagLabel, 'AGOTADO');
    expect(StockLevel.outOfStock.detailLabel, 'AGOTADO');
  });
}
