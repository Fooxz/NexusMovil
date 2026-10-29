import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_rpc.dart';
import '../../account/domain/account_models.dart';
import '../../catalog/domain/product.dart';
import '../../provider_portal/data/portal_json.dart';
import '../../provider_portal/domain/portal_models.dart';
import '../../vendor/domain/vendor_models.dart';
import '../domain/admin_console_models.dart';
import '../domain/admin_console_repository.dart';
import 'admin_console_json.dart';

/// Consola del administrador con las RPC `admin_*` de la parte 10.
class SupabaseAdminConsoleRepository implements AdminConsoleRepository {
  SupabaseAdminConsoleRepository(this._rpc);

  factory SupabaseAdminConsoleRepository.fromClient(SupabaseClient client) =>
      SupabaseAdminConsoleRepository(supabaseRpc(client));

  final SupabaseRpc _rpc;

  Future<T> _call<T>(String function, Map<String, Object?> params, T Function(Object?) parse) async {
    final json = await guardedRpc(_rpc, function, params);
    return parseResponse(() => parse(json));
  }

  static String? _search(String search) => search.trim().isEmpty ? null : search.trim();

  /// "2026-10-28": las fechas del filtro son días de Colombia.
  static String _day(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  @override
  Future<AdminDashboard> getDashboard() => _call('admin_get_dashboard', const {}, adminDashboardFromJson);

  @override
  Future<List<AdminProviderRow>> getProviders({
    String search = '',
    StoreStatus? status,
    ProviderSort sort = ProviderSort.name,
  }) => _call('admin_list_providers', {'search': ?_search(search), 'status': ?status?.name, 'sort': sort.name}, (json) {
    if (json is! List<Object?>) throw FormatException('Lista de tiendas inválida', json);
    return [for (final row in json) adminProviderRowFromJson(row)];
  });

  @override
  Future<ProviderOverview> getProviderOverview(String id) =>
      _call('admin_get_provider_overview', {'id': id}, providerOverviewFromJson);

  @override
  Future<ProviderOverview> addProviderNote(String id, ProviderNoteKind kind, String message) => _call(
    'admin_add_provider_note',
    {'id': id, 'kind': kind.wireName, 'message': message.trim()},
    providerOverviewFromJson,
  );

  @override
  Future<AdminOffersPage> getOffers({
    String search = '',
    String? providerId,
    ProductCategory? category,
    OfferModeration? moderation,
    QualityFlag? flag,
    bool anyFlag = false,
    int page = 0,
  }) => _call('admin_list_offers', {
    'search': ?_search(search),
    'provider': ?providerId,
    'category': ?category?.name,
    'moderation': ?moderation?.name,
    'flag': ?(anyFlag ? 'any' : flag?.wireName),
    'page': page,
  }, adminOffersPageFromJson);

  @override
  Future<AdminOfferDetail> getOffer(String offerId) =>
      _call('admin_get_offer', {'offer_id': offerId}, adminOfferDetailFromJson);

  @override
  Future<AdminOfferDetail> moderateOffer(String offerId, ModerationAction action, {String? reason}) => _call(
    'admin_moderate_offer',
    {'offer_id': offerId, 'action': action.name, 'reason': ?reason?.trim()},
    adminOfferDetailFromJson,
  );

  @override
  Future<List<AdminOffer>> updateProduct(String productId, AdminProductInput product) => _call('admin_update_product', {
    'product_id': productId,
    'product': product.toJson(),
  }, updatedProductOffersFromJson);

  @override
  Future<PortalPage<AdminOrderRow>> getOrders({
    String search = '',
    String? providerId,
    VendorOrderStatus? status,
    DateTime? from,
    DateTime? to,
    int page = 0,
  }) => _call('admin_list_orders', {
    'search': ?_search(search),
    'provider': ?providerId,
    'status': ?status?.name,
    'from_date': ?(from == null ? null : _day(from)),
    'to_date': ?(to == null ? null : _day(to)),
    'page': page,
  }, (json) => portalPageFromJson(json, adminOrderRowFromJson));

  @override
  Future<AdminOrderDetail> getOrder(String orderId) =>
      _call('admin_get_order', {'id': orderId}, adminOrderDetailFromJson);

  @override
  Future<AdminOrderDetail> updateSubOrderStatus(
    String subOrderId,
    VendorOrderStatus status, {
    required String note,
    String? carrier,
    String? trackingNumber,
  }) => _call('admin_update_sub_order_status', {
    'id': subOrderId,
    'status': status.name,
    'note': note.trim(),
    'carrier': ?carrier,
    'tracking_number': ?trackingNumber,
  }, adminOrderDetailFromJson);

  @override
  Future<AdminOrderDetail> addOrderNote(String orderId, String message, {String? subOrderId}) => _call(
    'admin_add_order_note',
    {'id': orderId, 'message': message.trim(), 'sub_order_id': ?subOrderId},
    adminOrderDetailFromJson,
  );
}
