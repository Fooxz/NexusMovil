// Prueba de integración contra el Supabase local con los datos de seed.sql.
// Se salta si no hay configuración. Para ejecutarla (backend levantado y
// `npx supabase db reset` recién hecho):
//
//   flutter test test/integration --dart-define-from-file=env.json
//
// con SUPABASE_URL = http://127.0.0.1:54321 en env.json.
@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/core/config/env.dart';
import 'package:prueba01/features/catalog/data/supabase_product_repository.dart';
import 'package:prueba01/features/catalog/domain/product.dart';
import 'package:prueba01/features/catalog/domain/product_filters.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/integration_support.dart';

void main() {
  const env = AppEnv.fromEnvironment();
  final skip = integrationSkip(env);

  late SupabaseProductRepository repository;

  setUpAll(() {
    if (skip != false) return;
    repository = SupabaseProductRepository.fromClient(
      SupabaseClient(env.supabaseUrl, env.supabasePublishableKey),
    );
  });

  test('lists only visible products with their best offer', () async {
    final page = await repository.getProducts(pageSize: 50);

    expect(page.total, greaterThan(500), reason: 'seed.sql más el catálogo generado (seeds/)');
    expect(page.items, hasLength(50));
    final vengeance = await repository.getById('corsair-vengeance-ddr5-32gb');
    // La oferta más barata es de un proveedor pendiente: no debe contar.
    expect(vengeance!.priceCents, 54990000);
    expect(
      (await repository.getById('kraken-elite-360'))!.stockLevel,
      StockLevel.outOfStock,
    );
  }, skip: skip);

  test('filters by category, brand, price and sorts by price', () async {
    final psus = await repository.getProducts(
      filters: const ProductFilters(
        category: ProductCategory.psu,
        sort: ProductSort.priceAsc,
      ),
    );
    final prices = psus.items.map((product) => product.priceCents).toList();
    expect(prices, [...prices]..sort(), reason: 'de menor a mayor precio');
    expect(psus.items.map((product) => product.category), everyElement(ProductCategory.psu));

    final nvidiaUnder2M = await repository.getProducts(
      filters: const ProductFilters(brand: 'nvidia', maxPriceCents: 200000000),
    );
    expect(nvidiaUnder2M.items, isNotEmpty);
    expect(nvidiaUnder2M.items.map((product) => product.priceCents), everyElement(lessThanOrEqualTo(200000000)));
    expect(nvidiaUnder2M.items.map((product) => product.id), contains('rtx-5080'));

    final accented = await repository.getProducts(
      filters: const ProductFilters(search: 'REFRIGERACIÓN'),
    );
    expect(accented.total, greaterThan(3));
    expect(accented.items.map((product) => product.category), everyElement(ProductCategory.cooling));
  }, skip: skip);

  test('detail brings provider offers; unknown ids are null', () async {
    final product = await repository.getById('rtx-5090');

    expect(product!.offers.map((offer) => offer.providerName), [
      'TecnoPartes',
      'Mundo PC',
    ]);
    expect(await repository.getById('no-existe'), isNull);
  }, skip: skip);

  test('related products and brands come from the backend', () async {
    final related = await repository.getRelated('rtx-5090', limit: 3);
    expect(related.map((product) => product.category), everyElement(ProductCategory.gpu),
        reason: 'primero los de la misma categoría');
    expect(related.map((product) => product.id), isNot(contains('rtx-5090')));

    final brands = await repository.getBrands(category: ProductCategory.gpu);
    expect(brands, containsAll(['AMD', 'NVIDIA', 'ASUS', 'MSI']));
  }, skip: skip);
}
