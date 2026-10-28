import '../../catalog/domain/product.dart';
import '../../provider_portal/domain/portal_models.dart';

/// Estado de un pedido para la tienda (su sub-orden; API_CONTRATO, parte 9).
/// Flujo: nuevo -> confirmado -> preparando -> enviado -> entregado.
enum VendorOrderStatus {
  pending,
  confirmed,
  preparing,
  shipped,
  delivered,
  rejected,
  cancelled,
  returned,
  incident;

  String get label => switch (this) {
    pending => 'Nuevo',
    confirmed => 'Confirmado',
    preparing => 'Preparando',
    shipped => 'Enviado',
    delivered => 'Entregado',
    rejected => 'Rechazado',
    cancelled => 'Cancelado',
    returned => 'Devuelto',
    incident => 'Con incidencia',
  };

  /// Texto del botón que lleva el pedido a este estado.
  String get actionLabel => switch (this) {
    pending => 'Nuevo',
    confirmed => 'Aceptar pedido',
    preparing => 'Empezar a preparar',
    shipped => 'Marcar como enviado',
    delivered => 'Marcar como entregado',
    rejected => 'Rechazar pedido',
    cancelled => 'Cancelar pedido',
    returned => 'Registrar devolución',
    incident => 'Reportar incidencia',
  };

  /// El backend exige el motivo para pasar a este estado.
  bool get needsNote => this == rejected || this == cancelled || this == returned || this == incident;

  /// Enviar exige la transportadora y la guía.
  bool get needsShipping => this == shipped;

  /// Avanza en el flujo normal (botón principal); los demás son alternativos.
  bool get isForward => this == confirmed || this == preparing || this == shipped || this == delivered;

  static VendorOrderStatus fromName(String name) =>
      values.asNameMap()[name] ?? (throw FormatException('Estado de pedido desconocido: $name'));
}

class VendorOrder {
  const VendorOrder({
    required this.id,
    required this.orderNumber,
    required this.createdAt,
    required this.status,
    required this.units,
    required this.subtotalCents,
    required this.commissionCents,
    required this.netCents,
    this.customerName,
    this.city,
    this.department,
    this.carrier,
    this.trackingNumber,
    this.hasBackorders = false,
  });

  /// Id de la sub-orden de la tienda.
  final String id;
  final String orderNumber;
  final DateTime createdAt;
  final VendorOrderStatus status;
  final int units;

  /// Lo que pagó el cliente por lo de esta tienda (IVA incluido).
  final int subtotalCents;
  final int commissionCents;

  /// Lo que recibe la tienda: subtotal menos la comisión de NEXUS.
  final int netCents;
  final String? customerName;
  final String? city;
  final String? department;
  final String? carrier;
  final String? trackingNumber;

  /// Algunas unidades ya no había en stock cuando se aprobó el pago.
  final bool hasBackorders;
}

class VendorOrderItem {
  const VendorOrderItem({
    required this.productId,
    required this.productName,
    required this.brand,
    required this.quantity,
    required this.unitPriceCents,
    required this.lineTotalCents,
    required this.commissionCents,
    required this.netCents,
    this.backorderedUnits = 0,
  });

  final String productId;
  final String productName;
  final String brand;
  final int quantity;
  final int unitPriceCents;
  final int lineTotalCents;
  final int commissionCents;
  final int netCents;
  final int backorderedUnits;
}

class OrderStatusChange {
  const OrderStatusChange({
    this.fromStatus,
    required this.toStatus,
    this.note,
    this.actorName,
    required this.createdAt,
  });

  final VendorOrderStatus? fromStatus;
  final VendorOrderStatus toStatus;
  final String? note;

  /// Quién lo hizo; null si fue el sistema (pago aprobado).
  final String? actorName;
  final DateTime createdAt;
}

/// Dónde entregar, copiado del checkout.
class ShippingAddress {
  const ShippingAddress({
    required this.recipientName,
    required this.phone,
    required this.department,
    required this.city,
    required this.addressLine,
    this.details,
  });

  final String recipientName;
  final String phone;
  final String department;
  final String city;
  final String addressLine;
  final String? details;
}

/// Contacto y facturación del cliente: la tienda vende y factura.
class CustomerContact {
  const CustomerContact({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.documentType,
    required this.documentNumber,
  });

  final String fullName;
  final String email;
  final String phone;
  final String documentType;
  final String documentNumber;
}

class VendorOrderDetail {
  const VendorOrderDetail({
    required this.order,
    this.statusNote,
    required this.shippingAddress,
    required this.contact,
    required this.nextStatuses,
    required this.items,
    required this.history,
  });

  final VendorOrder order;

  /// Motivo del último cambio (rechazo, cancelación, incidencia...).
  final String? statusNote;
  final ShippingAddress shippingAddress;
  final CustomerContact contact;

  /// Estados a los que puede pasar ahora (RN-029).
  final List<VendorOrderStatus> nextStatuses;
  final List<VendorOrderItem> items;
  final List<OrderStatusChange> history;
}

// --- Inventario ------------------------------------------------------------

enum StockAlert { low, out }

class InventoryItem {
  const InventoryItem({
    required this.offerId,
    required this.productId,
    required this.name,
    required this.brand,
    this.category,
    this.imageUrl,
    required this.status,
    required this.externalSku,
    required this.stockUnits,
    required this.minStock,
    required this.reservedUnits,
    required this.soldUnits,
    this.alert,
  });

  final String offerId;
  final String productId;
  final String name;
  final String brand;
  final ProductCategory? category;
  final String? imageUrl;
  final OfferStatus status;
  final String externalSku;

  /// Disponible para vender.
  final int stockUnits;

  /// Con [stockUnits] en este valor o menos, hay alerta de stock bajo.
  final int minStock;

  /// Vendidas y todavía sin enviar: ya se descontaron de [stockUnits].
  final int reservedUnits;

  /// Vendidas en pedidos no rechazados ni cancelados.
  final int soldUnits;
  final StockAlert? alert;
}

class InventoryPage {
  const InventoryPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.allCount,
    required this.lowCount,
    required this.outCount,
  });

  final List<InventoryItem> items;
  final int total;
  final int page;
  final int pageSize;
  final int allCount;
  final int lowCount;
  final int outCount;

  bool get hasMore => (page + 1) * pageSize < total;
}

enum StockMovementKind {
  entry,
  exit,
  adjustment,
  sale,
  cancellation;

  String get label => switch (this) {
    entry => 'Entrada',
    exit => 'Salida',
    adjustment => 'Ajuste',
    sale => 'Venta',
    cancellation => 'Devolución al stock',
  };

  /// Los que la tienda registra a mano.
  static const manual = [entry, exit, adjustment];
}

class StockMovement {
  const StockMovement({
    required this.id,
    required this.productId,
    required this.productName,
    required this.kind,
    required this.quantityDelta,
    required this.stockBefore,
    required this.stockAfter,
    this.reason,
    this.orderNumber,
    this.actorName,
    required this.createdAt,
  });

  final int id;
  final String productId;
  final String productName;
  final StockMovementKind kind;
  final int quantityDelta;
  final int stockBefore;
  final int stockAfter;
  final String? reason;
  final String? orderNumber;
  final String? actorName;
  final DateTime createdAt;
}

// --- Resumen ---------------------------------------------------------------

/// Ventas de un periodo y del anterior hasta el mismo momento.
class SalesPeriod {
  const SalesPeriod(this.currentCents, this.previousCents);

  final int currentCents;
  final int previousCents;

  /// Crecimiento en porcentaje; null si el periodo anterior no tuvo ventas.
  double? get growthPercent =>
      previousCents == 0 ? null : (currentCents - previousCents) * 100 / previousCents;
}

class VendorDashboard {
  const VendorDashboard({
    required this.today,
    required this.week,
    required this.month,
    required this.orderCounts,
    required this.activeOffers,
    required this.lowStock,
    required this.outOfStock,
    required this.lowStockItems,
    required this.grossCents,
    required this.commissionCents,
    required this.netCents,
    required this.pendingPayoutCents,
    required this.recentOrders,
  });

  final SalesPeriod today;
  final SalesPeriod week;
  final SalesPeriod month;

  /// Pedidos por estado. Cancelados incluye los rechazados.
  final Map<VendorOrderStatus, int> orderCounts;
  final int activeOffers;
  final int lowStock;
  final int outOfStock;
  final List<InventoryItem> lowStockItems;

  /// Del mes en curso.
  final int grossCents;
  final int commissionCents;
  final int netCents;

  /// Neto de los pedidos no cancelados que NEXUS aún no liquida.
  final int pendingPayoutCents;
  final List<VendorOrder> recentOrders;

  int ordersIn(VendorOrderStatus status) => orderCounts[status] ?? 0;
}
