import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/features/catalog/data/mock_product_repository.dart';
import 'package:prueba01/features/catalog/domain/product.dart';

void main() {
  late MockProductRepository repository;

  setUp(() {
    repository = MockProductRepository(latency: Duration.zero);
  });

  test('lists and paginates all products', () async {
    final firstPage = await repository.getProducts(pageSize: 4);
    final secondPage = await repository.getProducts(page: 1, pageSize: 4);

    expect(firstPage.total, 6);
    expect(firstPage.items, hasLength(4));
    expect(firstPage.hasMore, isTrue);
    expect(secondPage.items, hasLength(2));
    expect(secondPage.hasMore, isFalse);
  });

  test('searches product name and category', () async {
    final byName = await repository.getProducts(search: 'ryzen');
    final byCategory = await repository.getProducts(
      search: 'tarjetas gráficas',
    );

    expect(byName.items.map((product) => product.id), ['ryzen-9-9950x']);
    expect(byCategory.items.map((product) => product.id), [
      'rtx-5090',
      'rtx-5080',
    ]);
  });

  test('searches accented names and categories without accents', () async {
    final page = await repository.getProducts(search: 'tarjetas graficas');

    expect(page.items.map((product) => product.id), [
      'rtx-5090',
      'rtx-5080',
    ]);
  });

  test('generated repository returns the requested 200 products', () async {
    final generatedRepository = MockProductRepository.generated(
      200,
      latency: Duration.zero,
    );
    final firstPage = await generatedRepository.getProducts(pageSize: 50);
    final lastPage = await generatedRepository.getProducts(
      page: 3,
      pageSize: 50,
    );

    expect(firstPage.total, 200);
    expect(firstPage.items, hasLength(50));
    expect(lastPage.items, hasLength(50));
    expect(lastPage.items.last.id, 'generated-200');
    expect(lastPage.hasMore, isFalse);
  });

  test('filters by category', () async {
    final page = await repository.getProducts(
      category: ProductCategory.cooling,
    );

    expect(page.items.map((product) => product.id), [
      'kraken-elite-360',
      'cooler-master-elite-liquid-360',
    ]);
  });

  test('gets products by id and returns null for an unknown id', () async {
    expect(
      (await repository.getById('rtx-5090'))?.name,
      'NVIDIA GEFORCE RTX 5090',
    );
    expect(await repository.getById('missing'), isNull);
  });

  test('returns related products with matching category first', () async {
    final related = await repository.getRelated('rtx-5090');

    expect(related.map((product) => product.id), ['rtx-5080', 'ryzen-9-9950x']);
    expect(
      related,
      isNot(contains(predicate((Product p) => p.id == 'rtx-5090'))),
    );
  });

  test('respects the requested related-product limit', () async {
    final related = await repository.getRelated('rtx-5090', limit: 1);

    expect(related, hasLength(1));
    expect(related.single.id, 'rtx-5080');
  });
}
