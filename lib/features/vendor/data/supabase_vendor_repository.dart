import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_rpc.dart';
import '../../provider_portal/data/portal_json.dart';
import '../../provider_portal/domain/portal_models.dart';
import '../domain/vendor_models.dart';
import '../domain/vendor_repository.dart';
import 'vendor_json.dart';

/// Panel de la tienda con las RPC de la parte 9.
class SupabaseVendorRepository implements VendorRepository {
  SupabaseVendorRepository(this._rpc);

  factory SupabaseVendorRepository.fromClient(SupabaseClient client) =>
      SupabaseVendorRepository(supabaseRpc(client));

  final SupabaseRpc _rpc;

  Future<T> _call<T>(String function, Map<String, Object?> params, T Function(Object?) parse) async {
    final json = await guardedRpc(_rpc, function, params);
    return parseResponse(() => parse(json));
  }

  @override
  Future<VendorDashboard> getDashboard() => _call('get_my_dashboard', const {}, vendorDashboardFromJson);

  @override
  Future<PortalPage<VendorOrder>> getOrders({
    VendorOrderStatus? status,
    String search = '',
    int page = 0,
  }) => _call('get_my_orders', {
    'status': ?status?.name,
    if (search.trim().isNotEmpty) 'search': search.trim(),
    'page': page,
  }, (json) => portalPageFromJson(json, vendorOrderFromJson));

  @override
  Future<VendorOrderDetail> getOrder(String id) =>
      _call('get_my_order', {'id': id}, vendorOrderDetailFromJson);

  @override
  Future<VendorOrderDetail> updateOrderStatus(
    String id,
    VendorOrderStatus status, {
    String? note,
    String? carrier,
    String? trackingNumber,
  }) => _call('update_my_order_status', {
    'id': id,
    'status': status.name,
    'note': ?note,
    'carrier': ?carrier,
    'tracking_number': ?trackingNumber,
  }, vendorOrderDetailFromJson);

  @override
  Future<InventoryPage> getInventory({StockAlert? alert, String search = '', int page = 0}) =>
      _call('get_my_inventory', {
        'alert': ?alert?.name,
        if (search.trim().isNotEmpty) 'search': search.trim(),
        'page': page,
      }, inventoryPageFromJson);

  @override
  Future<InventoryItem> adjustStock(
    String productId,
    StockMovementKind kind,
    int quantity,
    String reason,
  ) => _call('adjust_my_stock', {
    'product_id': productId,
    'kind': kind.name,
    'quantity': quantity,
    'reason': reason.trim(),
  }, inventoryItemFromJson);

  @override
  Future<InventoryItem> setMinStock(String productId, int minStock) => _call(
    'set_my_min_stock',
    {'product_id': productId, 'min_stock': minStock},
    inventoryItemFromJson,
  );

  @override
  Future<PortalPage<StockMovement>> getMovements({String? productId, int page = 0}) => _call(
    'get_my_stock_movements',
    {'product_id': ?productId, 'page': page},
    (json) => portalPageFromJson(json, stockMovementFromJson),
  );
}
