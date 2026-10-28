import '../../provider_portal/domain/portal_models.dart';
import 'vendor_models.dart';

/// Panel de la tienda con sesión (API_CONTRATO, parte 9): resumen, pedidos e
/// inventario. El backend sabe de qué tienda es la cuenta: ningún método
/// recibe el id de la tienda. Los errores llegan como `AppFailure`.
abstract class VendorRepository {
  Future<VendorDashboard> getDashboard();

  /// Sin [status], todos. [search] busca por número de pedido o cliente.
  Future<PortalPage<VendorOrder>> getOrders({
    VendorOrderStatus? status,
    String search = '',
    int page = 0,
  });

  Future<VendorOrderDetail> getOrder(String id);

  /// Lanza `InvalidOrderTransitionFailure` si el pedido cambió y ya no admite
  /// ese estado, y `FieldValidationFailure` si falta el motivo o la guía.
  Future<VendorOrderDetail> updateOrderStatus(
    String id,
    VendorOrderStatus status, {
    String? note,
    String? carrier,
    String? trackingNumber,
  });

  Future<InventoryPage> getInventory({StockAlert? alert, String search = '', int page = 0});

  /// Entrada o salida de [quantity] unidades, o ajuste al conteo [quantity].
  Future<InventoryItem> adjustStock(
    String productId,
    StockMovementKind kind,
    int quantity,
    String reason,
  );

  Future<InventoryItem> setMinStock(String productId, int minStock);

  /// De un producto o de todos, del más reciente al más antiguo.
  Future<PortalPage<StockMovement>> getMovements({String? productId, int page = 0});
}
