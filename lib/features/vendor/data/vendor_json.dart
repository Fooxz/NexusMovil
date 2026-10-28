import '../../catalog/domain/product.dart';
import '../../provider_portal/data/portal_json.dart';
import '../domain/vendor_models.dart';

/// Lectura de las RPC del panel de la tienda (API_CONTRATO, parte 9). Lanzan
/// `FormatException` si falta un campo obligatorio.

String? _string(Map<Object?, Object?> json, String key) =>
    json[key] is String ? json[key] as String : null;

int _int(Map<Object?, Object?> json, String key) => switch (json[key]) {
  final int value => value,
  final num value => value.toInt(),
  _ => 0,
};

DateTime _date(Object? value, Object? json) =>
    value is String ? DateTime.parse(value) : throw FormatException('Fecha inválida', json);

VendorOrder vendorOrderFromJson(Object? json) {
  if (json case {
    'id': String id,
    'orderNumber': String orderNumber,
    'createdAt': String createdAt,
    'status': String status,
  }) {
    return VendorOrder(
      id: id,
      orderNumber: orderNumber,
      createdAt: DateTime.parse(createdAt),
      status: VendorOrderStatus.fromName(status),
      units: _int(json, 'units'),
      subtotalCents: _int(json, 'subtotalCents'),
      commissionCents: _int(json, 'commissionCents'),
      netCents: _int(json, 'netCents'),
      customerName: _string(json, 'customerName'),
      city: _string(json, 'city'),
      department: _string(json, 'department'),
      carrier: _string(json, 'carrier'),
      trackingNumber: _string(json, 'trackingNumber'),
      hasBackorders: json['hasBackorders'] == true,
    );
  }
  throw FormatException('Pedido inválido', json);
}

VendorOrderDetail vendorOrderDetailFromJson(Object? json) {
  if (json case {
    'shippingAddress': final Map<Object?, Object?> address,
    'contact': final Map<Object?, Object?> contact,
    'nextStatuses': final List<Object?> next,
    'items': final List<Object?> items,
    'history': final List<Object?> history,
  }) {
    return VendorOrderDetail(
      order: vendorOrderFromJson(json),
      statusNote: _string(json, 'statusNote'),
      shippingAddress: ShippingAddress(
        recipientName: _string(address, 'recipientName') ?? '',
        phone: _string(address, 'phone') ?? '',
        department: _string(address, 'department') ?? '',
        city: _string(address, 'city') ?? '',
        addressLine: _string(address, 'addressLine') ?? '',
        details: _string(address, 'details'),
      ),
      contact: CustomerContact(
        fullName: _string(contact, 'fullName') ?? '',
        email: _string(contact, 'email') ?? '',
        phone: _string(contact, 'phone') ?? '',
        documentType: _string(contact, 'documentType') ?? '',
        documentNumber: _string(contact, 'documentNumber') ?? '',
      ),
      nextStatuses: [for (final name in next.whereType<String>()) VendorOrderStatus.fromName(name)],
      items: [for (final item in items) _itemFromJson(item)],
      history: [for (final change in history) _changeFromJson(change)],
    );
  }
  throw FormatException('Detalle de pedido inválido', json);
}

VendorOrderItem _itemFromJson(Object? json) {
  if (json case {
    'productId': String productId,
    'productName': String productName,
    'brand': String brand,
    'quantity': int quantity,
  }) {
    return VendorOrderItem(
      productId: productId,
      productName: productName,
      brand: brand,
      quantity: quantity,
      unitPriceCents: _int(json, 'unitPriceCents'),
      lineTotalCents: _int(json, 'lineTotalCents'),
      commissionCents: _int(json, 'commissionCents'),
      netCents: _int(json, 'netCents'),
      backorderedUnits: _int(json, 'backorderedUnits'),
    );
  }
  throw FormatException('Ítem de pedido inválido', json);
}

OrderStatusChange _changeFromJson(Object? json) {
  if (json case {'toStatus': String to, 'createdAt': String createdAt}) {
    final from = _string(json, 'fromStatus');
    return OrderStatusChange(
      fromStatus: from == null ? null : VendorOrderStatus.fromName(from),
      toStatus: VendorOrderStatus.fromName(to),
      note: _string(json, 'note'),
      actorName: _string(json, 'actorName'),
      createdAt: DateTime.parse(createdAt),
    );
  }
  throw FormatException('Cambio de estado inválido', json);
}

InventoryItem inventoryItemFromJson(Object? json) {
  if (json case {
    'offerId': String offerId,
    'productId': String productId,
    'name': String name,
    'brand': String brand,
    'status': String status,
    'stockUnits': int stockUnits,
    'minStock': int minStock,
  }) {
    final category = _string(json, 'category');
    final alert = _string(json, 'alert');
    return InventoryItem(
      offerId: offerId,
      productId: productId,
      name: name,
      brand: brand,
      category: category == null ? null : ProductCategory.values.asNameMap()[category],
      imageUrl: _string(json, 'imageUrl'),
      status: offerStatusFromName(status),
      externalSku: _string(json, 'externalSku') ?? '',
      stockUnits: stockUnits,
      minStock: minStock,
      reservedUnits: _int(json, 'reservedUnits'),
      soldUnits: _int(json, 'soldUnits'),
      alert: alert == null ? null : StockAlert.values.asNameMap()[alert],
    );
  }
  throw FormatException('Ítem de inventario inválido', json);
}

InventoryPage inventoryPageFromJson(Object? json) {
  if (json case {
    'items': final List<Object?> items,
    'total': int total,
    'page': int page,
    'pageSize': int pageSize,
    'counts': final Map<Object?, Object?> counts,
  }) {
    return InventoryPage(
      items: [for (final item in items) inventoryItemFromJson(item)],
      total: total,
      page: page,
      pageSize: pageSize,
      allCount: _int(counts, 'all'),
      lowCount: _int(counts, 'low'),
      outCount: _int(counts, 'out'),
    );
  }
  throw FormatException('Inventario inválido', json);
}

StockMovement stockMovementFromJson(Object? json) {
  if (json case {
    'id': int id,
    'productId': String productId,
    'productName': String productName,
    'kind': String kind,
    'quantityDelta': int delta,
    'stockBefore': int before,
    'stockAfter': int after,
  }) {
    return StockMovement(
      id: id,
      productId: productId,
      productName: productName,
      kind: StockMovementKind.values.asNameMap()[kind] ??
          (throw FormatException('Movimiento desconocido: $kind', json)),
      quantityDelta: delta,
      stockBefore: before,
      stockAfter: after,
      reason: _string(json, 'reason'),
      orderNumber: _string(json, 'orderNumber'),
      actorName: _string(json, 'actorName'),
      createdAt: _date(json['createdAt'], json),
    );
  }
  throw FormatException('Movimiento de inventario inválido', json);
}

VendorDashboard vendorDashboardFromJson(Object? json) {
  if (json case {
    'sales': final Map<Object?, Object?> sales,
    'orders': final Map<Object?, Object?> orders,
    'inventory': final Map<Object?, Object?> inventory,
    'lowStockItems': final List<Object?> lowStockItems,
    'finance': final Map<Object?, Object?> finance,
    'recentOrders': final List<Object?> recentOrders,
  }) {
    return VendorDashboard(
      today: SalesPeriod(_int(sales, 'todayCents'), _int(sales, 'yesterdayCents')),
      week: SalesPeriod(_int(sales, 'weekCents'), _int(sales, 'previousWeekCents')),
      month: SalesPeriod(_int(sales, 'monthCents'), _int(sales, 'previousMonthCents')),
      orderCounts: {
        for (final status in VendorOrderStatus.values)
          if (orders.containsKey(status.name)) status: _int(orders, status.name),
      },
      activeOffers: _int(inventory, 'active'),
      lowStock: _int(inventory, 'lowStock'),
      outOfStock: _int(inventory, 'outOfStock'),
      lowStockItems: [for (final item in lowStockItems) inventoryItemFromJson(item)],
      grossCents: _int(finance, 'grossCents'),
      commissionCents: _int(finance, 'commissionCents'),
      netCents: _int(finance, 'netCents'),
      pendingPayoutCents: _int(finance, 'pendingPayoutCents'),
      recentOrders: [for (final order in recentOrders) vendorOrderFromJson(order)],
    );
  }
  throw FormatException('Resumen inválido', json);
}
