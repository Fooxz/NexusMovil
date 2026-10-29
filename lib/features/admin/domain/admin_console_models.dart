import '../../catalog/domain/product.dart';
import '../../provider_portal/domain/portal_models.dart';
import '../../vendor/domain/vendor_models.dart';
import 'admin_models.dart';

// --- Resumen global ----------------------------------------------------------

/// Alertas del resumen, con el número de casos (API_CONTRATO, parte 10).
enum AdminAlertKind {
  offersReview('offers_review'),
  ordersIncident('orders_incident'),
  ordersStale('orders_stale'),
  providersPending('providers_pending'),
  newProviders('new_providers'),
  paymentsError('payments_error'),
  paymentEventsUnknown('payment_events_unknown'),
  assistantUnavailable('assistant_unavailable');

  const AdminAlertKind(this.wireName);

  final String wireName;

  String label(int count) => switch (this) {
    offersReview => count == 1 ? '1 publicación pide revisión' : '$count publicaciones piden revisión',
    ordersIncident => count == 1 ? '1 pedido con incidencia' : '$count pedidos con incidencia',
    ordersStale =>
      count == 1 ? '1 pedido lleva más de 48 h sin respuesta' : '$count pedidos llevan más de 48 h sin respuesta',
    providersPending => count == 1 ? '1 tienda pendiente de habilitar' : '$count tiendas pendientes de habilitar',
    newProviders => count == 1 ? '1 tienda nueva esta semana' : '$count tiendas nuevas esta semana',
    paymentsError => count == 1 ? '1 pago con error en 30 días' : '$count pagos con error en 30 días',
    paymentEventsUnknown =>
      count == 1 ? '1 aviso de pago sin referencia conocida' : '$count avisos de pago sin referencia conocida',
    assistantUnavailable => count == 1 ? 'El asistente falló 1 vez en 24 h' : 'El asistente falló $count veces en 24 h',
  };

  static AdminAlertKind? fromWire(String name) {
    for (final kind in values) {
      if (kind.wireName == name) return kind;
    }
    return null;
  }
}

class AdminAlert {
  const AdminAlert(this.kind, this.count);

  final AdminAlertKind kind;
  final int count;
}

/// Un día de la serie de 30 días, en hora de Colombia.
class DailyPoint {
  const DailyPoint({
    required this.date,
    required this.salesCents,
    required this.commissionCents,
    required this.orders,
    required this.newCustomers,
    required this.newProviders,
  });

  final DateTime date;
  final int salesCents;
  final int commissionCents;
  final int orders;
  final int newCustomers;
  final int newProviders;
}

class CategorySales {
  const CategorySales({required this.category, required this.name, required this.salesCents, required this.units});

  final ProductCategory? category;
  final String name;
  final int salesCents;
  final int units;
}

class AdminDashboard {
  const AdminDashboard({
    required this.totalSalesCents,
    required this.totalCommissionCents,
    required this.today,
    required this.week,
    required this.month,
    required this.monthCommissionCents,
    required this.monthProviderNetCents,
    required this.totalOrders,
    required this.ordersInProgress,
    required this.ordersPending,
    required this.ordersDelivered,
    required this.ordersCancelled,
    required this.ordersReturned,
    required this.ordersIncident,
    required this.ordersStale,
    required this.customers,
    required this.activeCustomers,
    required this.newCustomers,
    required this.providersByStatus,
    required this.products,
    required this.visibleProducts,
    required this.outOfStockProducts,
    required this.offers,
    required this.hiddenOffers,
    required this.reviewOffers,
    required this.rejectedOffers,
    required this.flaggedOffers,
    required this.alerts,
    required this.series,
    required this.topCategories,
  });

  /// Ventas (IVA incluido) de los pedidos no rechazados ni cancelados.
  final int totalSalesCents;

  /// Ingreso de NEXUS: la comisión de esas ventas.
  final int totalCommissionCents;
  final SalesPeriod today;
  final SalesPeriod week;
  final SalesPeriod month;
  final int monthCommissionCents;
  final int monthProviderNetCents;

  final int totalOrders;
  final int ordersInProgress;
  final int ordersPending;
  final int ordersDelivered;

  /// Rechazados y cancelados.
  final int ordersCancelled;
  final int ordersReturned;
  final int ordersIncident;

  /// Nuevos sin respuesta de la tienda en 48 h.
  final int ordersStale;

  final int customers;

  /// Iniciaron sesión en los últimos 30 días.
  final int activeCustomers;

  /// Se registraron en los últimos 30 días.
  final int newCustomers;
  final Map<String, int> providersByStatus;

  final int products;

  /// Con al menos una oferta visible.
  final int visibleProducts;
  final int outOfStockProducts;
  final int offers;
  final int hiddenOffers;
  final int reviewOffers;
  final int rejectedOffers;

  /// Publicadas, aprobadas y con alguna alerta de calidad.
  final int flaggedOffers;
  final List<AdminAlert> alerts;
  final List<DailyPoint> series;
  final List<CategorySales> topCategories;

  int providersIn(String status) => providersByStatus[status] ?? 0;
}

// --- Proveedores -------------------------------------------------------------

enum ProviderSort {
  name('Nombre'),
  sales('Ventas (30 días)'),
  performance('Entregas cumplidas'),
  recent('Más recientes');

  const ProviderSort(this.label);

  final String label;
}

class ProviderMetrics {
  const ProviderMetrics({
    this.sales30dCents = 0,
    this.commission30dCents = 0,
    this.orders = 0,
    this.openOrders = 0,
    this.incidents = 0,
    this.deliveredRate,
    this.cancelRate,
    this.warnings = 0,
  });

  final int sales30dCents;
  final int commission30dCents;
  final int orders;

  /// Sin cerrar: nuevos, en curso o con incidencia.
  final int openOrders;
  final int incidents;

  /// Entregados sobre los pedidos cerrados (0 a 1); null sin pedidos cerrados.
  final double? deliveredRate;

  /// Rechazados o cancelados sobre los cerrados.
  final double? cancelRate;

  /// Advertencias, incidencias e incumplimientos registrados por NEXUS.
  final int warnings;
}

class AdminProviderRow {
  const AdminProviderRow({required this.store, required this.metrics, this.createdAt});

  final AdminStore store;
  final ProviderMetrics metrics;
  final DateTime? createdAt;
}

/// Tipos del historial administrativo de una tienda.
enum ProviderNoteKind {
  note('note', 'Observación'),
  warning('warning', 'Advertencia'),
  incident('incident', 'Incidencia recurrente'),
  policyViolation('policy_violation', 'Incumplimiento de políticas'),
  statusChange('status_change', 'Cambio de estado');

  const ProviderNoteKind(this.wireName, this.label);

  final String wireName;
  final String label;

  /// Las que el administrador registra a mano.
  static const manual = [note, warning, incident, policyViolation];

  static ProviderNoteKind fromWire(String name) {
    for (final kind in values) {
      if (kind.wireName == name) return kind;
    }
    return note;
  }
}

class ProviderNote {
  const ProviderNote({
    required this.id,
    required this.kind,
    required this.message,
    this.fromStatus,
    this.toStatus,
    this.actorName,
    required this.createdAt,
  });

  final int id;
  final ProviderNoteKind kind;
  final String message;
  final String? fromStatus;
  final String? toStatus;
  final String? actorName;
  final DateTime createdAt;
}

class ProviderInventorySummary {
  const ProviderInventorySummary({
    this.published = 0,
    this.lowStock = 0,
    this.outOfStock = 0,
    this.hidden = 0,
    this.rejected = 0,
  });

  final int published;
  final int lowStock;
  final int outOfStock;

  /// Ocultas por NEXUS o esperando revisión.
  final int hidden;
  final int rejected;
}

/// Todo lo de una tienda para supervisarla.
class ProviderOverview {
  const ProviderOverview({
    required this.store,
    required this.metrics,
    required this.inventory,
    required this.ordersByStatus,
    required this.recentOrders,
    required this.notes,
  });

  final AdminStore store;
  final ProviderMetrics metrics;
  final ProviderInventorySummary inventory;
  final Map<VendorOrderStatus, int> ordersByStatus;
  final List<AdminOrderRow> recentOrders;

  /// Del más reciente al más antiguo.
  final List<ProviderNote> notes;
}

// --- Catálogo y moderación -------------------------------------------------

/// Alertas de calidad de una oferta.
enum QualityFlag {
  incomplete('incomplete', 'Ficha incompleta'),
  priceAnomaly('price_anomaly', 'Precio anómalo'),
  duplicate('duplicate', 'Posible duplicado');

  const QualityFlag(this.wireName, this.label);

  final String wireName;
  final String label;

  static QualityFlag? fromWire(String name) {
    for (final flag in values) {
      if (flag.wireName == name) return flag;
    }
    return null;
  }
}

enum ModerationAction { approve, hide, reject }

class AdminOffer {
  const AdminOffer({
    required this.offerId,
    required this.productId,
    required this.productName,
    required this.brand,
    this.model,
    this.category,
    required this.providerId,
    required this.providerName,
    required this.providerStatus,
    required this.priceCents,
    this.oldPriceCents,
    required this.stockUnits,
    required this.status,
    required this.moderation,
    this.moderationReason,
    this.moderatedAt,
    this.imageUrl,
    this.flags = const [],
    required this.visible,
    required this.updatedAt,
  });

  final String offerId;
  final String productId;
  final String productName;
  final String brand;
  final String? model;
  final ProductCategory? category;
  final String providerId;
  final String providerName;
  final String providerStatus;
  final int priceCents;
  final int? oldPriceCents;
  final int stockUnits;
  final OfferStatus status;
  final OfferModeration moderation;
  final String? moderationReason;
  final DateTime? moderatedAt;
  final String? imageUrl;
  final List<QualityFlag> flags;

  /// Se ve en el catálogo: publicada, aprobada y con la tienda activa.
  final bool visible;
  final DateTime updatedAt;
}

/// Otra tienda que vende el mismo producto.
class SiblingOffer {
  const SiblingOffer({
    required this.offerId,
    required this.providerName,
    required this.priceCents,
    required this.stockUnits,
    required this.status,
    required this.moderation,
  });

  final String offerId;
  final String providerName;
  final int priceCents;
  final int stockUnits;
  final OfferStatus status;
  final OfferModeration moderation;
}

class AdminOfferDetail {
  const AdminOfferDetail({
    required this.offer,
    this.summary,
    this.attributes = const {},
    this.images = const [],
    this.otherOffers = const [],
  });

  final AdminOffer offer;
  final String? summary;

  /// Atributos técnicos por clave, como en `MyOfferDetail`.
  final Map<String, Object?> attributes;
  final List<String> images;
  final List<SiblingOffer> otherOffers;
}

class AdminOffersPage {
  const AdminOffersPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.counts,
  });

  final List<AdminOffer> items;
  final int total;
  final int page;
  final int pageSize;

  /// Con la búsqueda y los filtros de tienda y categoría: `all`, `approved`,
  /// `hidden`, `review`, `rejected` y `flagged`.
  final Map<String, int> counts;

  bool get hasMore => (page + 1) * pageSize < total;
}

/// Ficha corregida por el administrador. La ficha para mostrar sale de los
/// atributos, como en el formulario de la tienda.
class AdminProductInput {
  const AdminProductInput({
    required this.category,
    required this.name,
    required this.brand,
    required this.model,
    this.summary,
    this.attributes = const {},
    this.specs = const [],
    this.quickSpecs = const [],
  });

  final ProductCategory category;
  final String name;
  final String brand;
  final String model;
  final String? summary;
  final Map<String, Object?> attributes;
  final List<ProductSpec> specs;
  final List<String> quickSpecs;

  Map<String, Object?> toJson() => {
    'category': category.name,
    'name': name.trim(),
    'brand': brand.trim(),
    'model': model.trim(),
    if (summary != null && summary!.trim().isNotEmpty) 'summary': summary!.trim(),
    'attributes': attributes,
    'specs': [
      for (final spec in specs) {'label': spec.label, 'value': spec.value},
    ],
    'quickSpecs': quickSpecs,
  };
}

// --- Pedidos ---------------------------------------------------------------

/// Una sub-orden en la lista global: el pedido de una tienda.
class AdminOrderRow {
  const AdminOrderRow({
    required this.order,
    required this.orderId,
    required this.providerId,
    required this.providerName,
    this.customerEmail,
    this.paymentMethod,
  });

  /// La sub-orden, como la ve la tienda.
  final VendorOrder order;
  final String orderId;
  final String providerId;
  final String providerName;
  final String? customerEmail;
  final String? paymentMethod;
}

class PaymentInfo {
  const PaymentInfo({
    required this.reference,
    required this.status,
    required this.amountCents,
    this.method,
    this.transactionId,
    this.approvedAt,
  });

  final String reference;
  final String status;
  final int amountCents;
  final String? method;
  final String? transactionId;
  final DateTime? approvedAt;
}

class AdminSubOrder {
  const AdminSubOrder({
    required this.detail,
    required this.providerId,
    required this.providerName,
    required this.adminNextStatuses,
  });

  final VendorOrderDetail detail;
  final String providerId;
  final String providerName;

  /// Estados a los que el administrador la puede llevar al intervenir.
  final List<VendorOrderStatus> adminNextStatuses;
}

class OrderNote {
  const OrderNote({required this.id, this.subOrderId, required this.message, this.actorName, required this.createdAt});

  final int id;
  final String? subOrderId;
  final String message;
  final String? actorName;
  final DateTime createdAt;
}

class AdminOrderDetail {
  const AdminOrderDetail({
    required this.id,
    required this.number,
    required this.createdAt,
    required this.totalCents,
    required this.contact,
    required this.shippingAddress,
    required this.payment,
    required this.subOrders,
    required this.notes,
  });

  final String id;
  final String number;
  final DateTime createdAt;
  final int totalCents;
  final CustomerContact contact;
  final ShippingAddress shippingAddress;
  final PaymentInfo payment;
  final List<AdminSubOrder> subOrders;
  final List<OrderNote> notes;
}
