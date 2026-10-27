import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/core/errors/app_failure.dart';
import 'package:prueba01/features/catalog/data/supabase_product_repository.dart';
import 'package:prueba01/features/catalog/domain/product.dart';
import 'package:prueba01/features/catalog/domain/product_filters.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/contract_fixtures.dart';

/// Registra cada llamada RPC y responde con [respond].
class _FakeRpc {
  _FakeRpc(this.respond);

  final FutureOr<Object?> Function(String function, Map<String, Object?> params)
  respond;
  final calls = <({String function, Map<String, Object?> params})>[];

  Future<Object?> call(String function, Map<String, Object?> params) async {
    calls.add((function: function, params: params));
    return respond(function, params);
  }
}

void main() {
  test('sends the contract RPC parameters for the listing', () async {
    final rpc = _FakeRpc((_, _) => contractListingFixture);
    final repository = SupabaseProductRepository(rpc.call);

    final page = await repository.getProducts(
      page: 2,
      pageSize: 10,
      filters: const ProductFilters(
        search: '  rtx  ',
        category: ProductCategory.pcCase,
        brand: 'Lian Li',
        minPriceCents: 100000,
        maxPriceCents: 900000,
        sort: ProductSort.priceDesc,
      ),
    );

    expect(page.items, hasLength(2));
    expect(rpc.calls.single.function, 'get_products');
    expect(rpc.calls.single.params, {
      'page': 2,
      'page_size': 10,
      'search': 'rtx',
      'category': 'pcCase',
      'brand': 'Lian Li',
      'min_price_cents': 100000,
      'max_price_cents': 900000,
      'sort': 'priceDesc',
    });
  });

  test('omits empty filters', () async {
    final rpc = _FakeRpc((_, _) => contractListingFixture);

    await SupabaseProductRepository(rpc.call).getProducts();

    expect(rpc.calls.single.params, {
      'page': 0,
      'page_size': 20,
      'sort': 'relevance',
    });
  });

  test('reads the detail with offers', () async {
    final rpc = _FakeRpc((_, _) => contractDetailFixture);

    final product = await SupabaseProductRepository(rpc.call).getById('gpu-rtx-5090');

    expect(rpc.calls.single.function, 'get_product');
    expect(rpc.calls.single.params, {'id': 'gpu-rtx-5090'});
    expect(product!.offers.single.providerName, 'TecnoPartes SAS');
  });

  test('PRODUCT_NOT_FOUND becomes null in detail and empty related', () async {
    final rpc = _FakeRpc(
      (_, _) => throw const PostgrestException(
        message: 'No existe el producto x',
        code: 'PRODUCT_NOT_FOUND',
      ),
    );
    final repository = SupabaseProductRepository(rpc.call);

    expect(await repository.getById('x'), isNull);
    expect(await repository.getRelated('x'), isEmpty);
  });

  test('related uses max_items and skips the call for limit 0', () async {
    final rpc = _FakeRpc((_, _) => [contractDetailFixture]);
    final repository = SupabaseProductRepository(rpc.call);

    final related = await repository.getRelated('rtx-5080', limit: 3);
    final none = await repository.getRelated('rtx-5080', limit: 0);

    expect(related.single.id, 'gpu-rtx-5090');
    expect(none, isEmpty);
    expect(rpc.calls.single.params, {'id': 'rtx-5080', 'max_items': 3});
  });

  test('reads brands for the selected scope', () async {
    final rpc = _FakeRpc((_, _) => ['AMD', 'NVIDIA']);

    final brands = await SupabaseProductRepository(rpc.call)
        .getBrands(category: ProductCategory.gpu);

    expect(brands, ['AMD', 'NVIDIA']);
    expect(rpc.calls.single.function, 'get_catalog_brands');
    expect(rpc.calls.single.params, {'category': 'gpu'});
  });

  test('maps errors to AppFailure', () async {
    Future<void> expectFailure(Object error, Matcher matcher) async {
      final repository = SupabaseProductRepository(
        _FakeRpc((_, _) => throw error).call,
      );
      await expectLater(repository.getProducts(), throwsA(matcher));
    }

    await expectFailure(
      const PostgrestException(message: 'x', code: 'VALIDATION_ERROR'),
      isA<ValidationFailure>(),
    );
    await expectFailure(
      const PostgrestException(message: 'x', code: 'INTERNAL_ERROR'),
      isA<UnexpectedFailure>(),
    );
    await expectFailure(TimeoutException('sin respuesta'), isA<NetworkFailure>());
  });

  test('an invalid response is an UnexpectedFailure', () async {
    final repository = SupabaseProductRepository(
      _FakeRpc((_, _) => {'items': 'no es una lista'}).call,
    );

    await expectLater(repository.getProducts(), throwsA(isA<UnexpectedFailure>()));
  });
}
