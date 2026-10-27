import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../domain/product.dart';
import '../domain/product_filters.dart';
import '../domain/product_page.dart';
import '../domain/product_repository.dart';
import 'product_json.dart';

/// Llama a una RPC de Supabase y devuelve el JSON ya decodificado.
typedef RpcCall =
    Future<Object?> Function(String function, Map<String, Object?> params);

/// Catálogo real: las RPC de docs/API_CONTRATO.md, sección 3.4.
///
/// El cliente de Supabase decodifica el JSON fuera del hilo de UI; aquí solo
/// se convierten mapas en objetos (a lo sumo 50 productos por página), así que
/// no hace falta `compute` (R5).
class SupabaseProductRepository implements ProductRepository {
  SupabaseProductRepository(this._rpc);

  factory SupabaseProductRepository.fromClient(SupabaseClient client) =>
      SupabaseProductRepository(
        (function, params) => client.rpc<Object?>(function, params: params),
      );

  final RpcCall _rpc;

  @override
  Future<ProductPage> getProducts({
    int page = 0,
    int pageSize = 20,
    ProductFilters filters = const ProductFilters(),
  }) async {
    final json = await _call('get_products', {
      'page': page,
      'page_size': pageSize,
      if (filters.search.trim().isNotEmpty) 'search': filters.search.trim(),
      if (filters.category != null) 'category': filters.category!.name,
      if (filters.brand != null) 'brand': filters.brand,
      if (filters.minPriceCents != null)
        'min_price_cents': filters.minPriceCents,
      if (filters.maxPriceCents != null)
        'max_price_cents': filters.maxPriceCents,
      'sort': filters.sort.name,
    });
    return _parse(() => productPageFromJson(json));
  }

  @override
  Future<Product?> getById(String id) async {
    try {
      final json = await _call('get_product', {'id': id});
      return _parse<Product?>(() => productFromJson(json));
    } on NotFoundFailure {
      return null;
    }
  }

  @override
  Future<List<Product>> getRelated(String id, {int limit = 2}) async {
    if (limit <= 0) return const [];
    try {
      final json = await _call('get_related', {'id': id, 'max_items': limit});
      return _parse<List<Product>>(() => productListFromJson(json));
    } on NotFoundFailure {
      return const [];
    }
  }

  @override
  Future<List<String>> getBrands({ProductCategory? category}) async {
    final json = await _call('get_catalog_brands', {
      if (category != null) 'category': category.name,
    });
    return _parse(() {
      if (json is! List<Object?>) {
        throw FormatException('Lista de marcas inválida', json);
      }
      return [
        for (final brand in json)
          if (brand is String) brand,
      ];
    });
  }

  /// Traduce los errores de Supabase y de red a `AppFailure`.
  Future<Object?> _call(String function, Map<String, Object?> params) async {
    try {
      return await _rpc(function, params);
    } on PostgrestException catch (error) {
      throw AppFailure.fromApiError(code: error.code, details: error.details);
    } on AppFailure {
      rethrow;
    } on Exception {
      // Sin respuesta del servidor: ClientException, SocketException, timeout.
      throw const NetworkFailure();
    }
  }

  T _parse<T>(T Function() parse) {
    try {
      return parse();
    } on FormatException {
      throw const UnexpectedFailure();
    }
  }
}
