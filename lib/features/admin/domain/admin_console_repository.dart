import '../../account/domain/account_models.dart';
import '../../catalog/domain/product.dart';
import '../../provider_portal/domain/portal_models.dart';
import '../../vendor/domain/vendor_models.dart';
import 'admin_console_models.dart';

/// Consola del administrador (API_CONTRATO, parte 10): resumen global,
/// supervisión de tiendas, moderación del catálogo y pedidos de todas las
/// tiendas. El backend exige el rol administrador en cada llamada. Los
/// errores llegan como `AppFailure`.
abstract class AdminConsoleRepository {
  Future<AdminDashboard> getDashboard();

  Future<List<AdminProviderRow>> getProviders({
    String search = '',
    StoreStatus? status,
    ProviderSort sort = ProviderSort.name,
  });

  Future<ProviderOverview> getProviderOverview(String id);

  /// Advertencia, incidencia, incumplimiento u observación sobre una tienda.
  Future<ProviderOverview> addProviderNote(String id, ProviderNoteKind kind, String message);

  /// [flag] null: todas; [anyFlag]: con alguna alerta.
  Future<AdminOffersPage> getOffers({
    String search = '',
    String? providerId,
    ProductCategory? category,
    OfferModeration? moderation,
    QualityFlag? flag,
    bool anyFlag = false,
    int page = 0,
  });

  Future<AdminOfferDetail> getOffer(String offerId);

  /// Ocultar y rechazar exigen el [reason], que ve la tienda.
  Future<AdminOfferDetail> moderateOffer(String offerId, ModerationAction action, {String? reason});

  /// Corrige la ficha compartida del producto. Devuelve sus ofertas.
  Future<List<AdminOffer>> updateProduct(String productId, AdminProductInput product);

  Future<PortalPage<AdminOrderRow>> getOrders({
    String search = '',
    String? providerId,
    VendorOrderStatus? status,
    DateTime? from,
    DateTime? to,
    int page = 0,
  });

  Future<AdminOrderDetail> getOrder(String orderId);

  /// Interviene una sub-orden. La [note] es obligatoria y queda en el
  /// historial del pedido.
  Future<AdminOrderDetail> updateSubOrderStatus(
    String subOrderId,
    VendorOrderStatus status, {
    required String note,
    String? carrier,
    String? trackingNumber,
  });

  Future<AdminOrderDetail> addOrderNote(String orderId, String message, {String? subOrderId});
}
