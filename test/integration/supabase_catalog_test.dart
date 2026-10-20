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

    expect(page.total, 15);
    final vengeance = page.items.firstWhere(
      (product) => product.id == 'corsair-vengeance-ddr5-32gb',
    );
    // La oferta más barata es de un proveedor pendiente: no debe contar.
    expect(vengeance.priceCents, 54990000);
    expect(
      page.items.firstWhere((p) => p.id == 'kraken-elite-360').stockLevel,
      StockLevel.outOfStock,
    );
  }, skip: skip);

  test('filters by family, brand, price and sorts by price', () async {
    final prebuilt = await repository.getProducts(
      filters: const ProductFilters(
        family: ProductFamily.prebuiltPc,
        sort: ProductSort.priceAsc,
      ),
    );
    expect(prebuilt.items.map((product) => product.id), [
      'pc-oficina-i5-14400',
      'pc-gamer-pro-r7-5070',
      'pc-workstation-r9-5080',
    ]);

    final nvidiaUnder2M = await repository.getProducts(
      filters: const ProductFilters(brand: 'nvidia', maxPriceCents: 200000000),
    );
    expect(nvidiaUnder2M.items.map((product) => product.id), ['rtx-5080']);

    final accented = await repository.getProducts(
      filters: const ProductFilters(search: 'REFRIGERACIÓN'),
    );
    expect(accented.total, 2);
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
    expect(related.first.id, 'rtx-5080');
    expect(related.map((product) => product.id), isNot(contains('rtx-5090')));

    final brands = await repository.getBrands(family: ProductFamily.prebuiltPc);
    expect(brands, ['Mundo PC', 'TecnoPartes']);
  }, skip: skip);
}
