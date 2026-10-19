import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../catalog/data/supabase_product_repository.dart' show RpcCall;
import '../domain/cart_models.dart';
import '../domain/cart_repository.dart';
import 'cart_json.dart';

/// Carrito con las RPC de docs/API_CONTRATO.md, parte 2. El backend valida
/// cada cantidad contra el stock.
class SupabaseCartRepository implements CartRepository {
  SupabaseCartRepository(this._rpc);

  factory SupabaseCartRepository.fromClient(SupabaseClient client) =>
      SupabaseCartRepository(
        (function, params) => client.rpc<Object?>(function, params: params),
      );

  final RpcCall _rpc;

  @override
  Future<List<CartItem>> preview(List<CartEntry> entries) async {
    if (entries.isEmpty) return const [];
    return _call('preview_cart', {'items': _entries(entries)});
  }

  @override
  Future<List<CartItem>> load() => _call('get_cart', const {});

  @override
  Future<List<CartItem>> add(String offerId, int quantity) =>
      _call('add_cart_item', {'offer_id': offerId, 'quantity': quantity});

  @override
  Future<List<CartItem>> setQuantity(String offerId, int quantity) =>
      _call('set_cart_item', {'offer_id': offerId, 'quantity': quantity});

  @override
  Future<List<CartItem>> remove(String offerId) =>
      _call('remove_cart_item', {'offer_id': offerId});

  @override
  Future<List<CartItem>> clear() => _call('clear_cart', const {});

  @override
  Future<List<CartItem>> merge(List<CartEntry> entries) =>
      _call('merge_cart', {'items': _entries(entries)});

  static List<Map<String, Object>> _entries(List<CartEntry> entries) => [
    for (final entry in entries) entry.toJson(),
  ];

  Future<List<CartItem>> _call(
    String function,
    Map<String, Object?> params,
  ) async {
    final Object? json;
    try {
      json = await _rpc(function, params);
    } on PostgrestException catch (error) {
      throw AppFailure.fromApiError(code: error.code, details: error.details);
    } on AppFailure {
      rethrow;
    } on Exception {
      throw const NetworkFailure();
    }
    try {
      return cartItemsFromJson(json);
    } on FormatException {
      throw const UnexpectedFailure();
    }
  }
}
