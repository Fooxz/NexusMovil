import '../../catalog/domain/product.dart';
import '../../provider_portal/data/portal_json.dart';
import '../../provider_portal/domain/portal_models.dart';
import '../../vendor/data/vendor_json.dart';
import '../../vendor/domain/vendor_models.dart';
import '../domain/admin_console_models.dart';
import 'admin_json.dart';

/// Lectura de las RPC de la consola del administrador (API_CONTRATO, parte
/// 10). Lanzan `FormatException` si falta un campo obligatorio.

String? _string(Map<Object?, Object?> json, String key) => json[key] is String ? json[key] as String : null;

int _int(Map<Object?, Object?> json, String key) => switch (json[key]) {
  final num value => value.toInt(),
  _ => 0,
};

double? _double(Map<Object?, Object?> json, String key) => switch (json[key]) {
  final num value => value.toDouble(),
  _ => null,
};

DateTime? _date(Map<Object?, Object?> json, String key) =>
    json[key] is String ? DateTime.tryParse(json[key] as String) : null;

Map<Object?, Object?> _map(Object? value) => value is Map<Object?, Object?> ? value : const {};

List<Object?> _list(Object? value) => value is List<Object?> ? value : const [];

ProductCategory? _category(String? name) => name == null ? null : ProductCategory.values.asNameMap()[name];

AdminDashboard adminDashboardFromJson(Object? json) {
  if (json case {
    'sales': final Map<Object?, Object?> sales,
    'orders': final Map<Object?, Object?> orders,
    'users': final Map<Object?, Object?> users,
    'catalog': final Map<Object?, Object?> catalog,
  }) {
    return AdminDashboard(
      totalSalesCents: _int(sales, 'totalCents'),
      totalCommissionCents: _int(sales, 'totalCommissionCents'),
      today: SalesPeriod(_int(sales, 'todayCents'), _int(sales, 'yesterdayCents')),
      week: SalesPeriod(_int(sales, 'weekCents'), _int(sales, 'previousWeekCents')),
      month: SalesPeriod(_int(sales, 'monthCents'), _int(sales, 'previousMonthCents')),
      monthCommissionCents: _int(sales, 'monthCommissionCents'),
      monthProviderNetCents: _int(sales, 'monthProviderNetCents'),
      totalOrders: _int(orders, 'total'),
      ordersInProgress: _int(orders, 'inProgress'),
      ordersPending: _int(orders, 'pending'),
      ordersDelivered: _int(orders, 'delivered'),
      ordersCancelled: _int(orders, 'cancelled'),
      ordersReturned: _int(orders, 'returned'),
      ordersIncident: _int(orders, 'incident'),
      ordersStale: _int(orders, 'stale'),
      customers: _int(users, 'customers'),
      activeCustomers: _int(users, 'activeCustomers'),
      newCustomers: _int(users, 'newCustomers'),
      providersByStatus: {
        for (final entry in _map(users['providers']).entries)
          if (entry.value is num) '${entry.key}': (entry.value! as num).toInt(),
      },
      products: _int(catalog, 'products'),
      visibleProducts: _int(catalog, 'visibleProducts'),
      outOfStockProducts: _int(catalog, 'outOfStockProducts'),
      offers: _int(catalog, 'offers'),
      hiddenOffers: _int(catalog, 'hidden'),
      reviewOffers: _int(catalog, 'review'),
      rejectedOffers: _int(catalog, 'rejected'),
      flaggedOffers: _int(catalog, 'flagged'),
      alerts: [
        for (final alert in _list(json['alerts']))
          if (alert case {'kind': String kind, 'count': num count})
            if (AdminAlertKind.fromWire(kind) case final known?) AdminAlert(known, count.toInt()),
      ],
      series: [
        for (final day in _list(json['series']))
          if (day case {'date': String date})
            DailyPoint(
              date: DateTime.parse(date),
              salesCents: _int(day, 'salesCents'),
              commissionCents: _int(day, 'commissionCents'),
              orders: _int(day, 'orders'),
              newCustomers: _int(day, 'newCustomers'),
              newProviders: _int(day, 'newProviders'),
            ),
      ],
      topCategories: [
        for (final row in _list(json['topCategories']))
          if (row case {'category': String category, 'name': String name})
            CategorySales(
              category: _category(category),
              name: name,
              salesCents: _int(row, 'salesCents'),
              units: _int(row, 'units'),
            ),
      ],
    );
  }
  throw FormatException('Resumen inválido', json);
}

ProviderMetrics providerMetricsFromJson(Object? json) {
  final metrics = _map(json);
  return ProviderMetrics(
    sales30dCents: _int(metrics, 'sales30dCents'),
    commission30dCents: _int(metrics, 'commission30dCents'),
    orders: _int(metrics, 'orders'),
    openOrders: _int(metrics, 'openOrders'),
    incidents: _int(metrics, 'incidents'),
    deliveredRate: _double(metrics, 'deliveredRate'),
    cancelRate: _double(metrics, 'cancelRate'),
    warnings: _int(metrics, 'warnings'),
  );
}

AdminProviderRow adminProviderRowFromJson(Object? json) {
  final map = _map(json);
  return AdminProviderRow(
    store: adminStoreFromJson(json),
    metrics: providerMetricsFromJson(map['metrics']),
    createdAt: _date(map, 'createdAt'),
  );
}

ProviderNote _noteFromJson(Object? json) {
  if (json case {'id': int id, 'kind': String kind, 'message': String message, 'createdAt': String createdAt}) {
    return ProviderNote(
      id: id,
      kind: ProviderNoteKind.fromWire(kind),
      message: message,
      fromStatus: _string(json, 'fromStatus'),
      toStatus: _string(json, 'toStatus'),
      actorName: _string(json, 'actorName'),
      createdAt: DateTime.parse(createdAt),
    );
  }
  throw FormatException('Nota de la tienda inválida', json);
}

ProviderOverview providerOverviewFromJson(Object? json) {
  if (json case {
    'metrics': final Object metrics,
    'inventory': final Map<Object?, Object?> inventory,
    'ordersByStatus': final Map<Object?, Object?> ordersByStatus,
    'recentOrders': final List<Object?> recentOrders,
    'notes': final List<Object?> notes,
  }) {
    return ProviderOverview(
      store: adminStoreFromJson(json),
      metrics: providerMetricsFromJson(metrics),
      inventory: ProviderInventorySummary(
        published: _int(inventory, 'published'),
        lowStock: _int(inventory, 'lowStock'),
        outOfStock: _int(inventory, 'outOfStock'),
        hidden: _int(inventory, 'hidden'),
        rejected: _int(inventory, 'rejected'),
      ),
      ordersByStatus: {
        for (final status in VendorOrderStatus.values)
          if (ordersByStatus.containsKey(status.name)) status: _int(ordersByStatus, status.name),
      },
      recentOrders: [for (final order in recentOrders) adminOrderRowFromJson(order)],
      notes: [for (final note in notes) _noteFromJson(note)],
    );
  }
  throw FormatException('Tienda inválida', json);
}

AdminOffer adminOfferFromJson(Object? json) {
  if (json case {
    'offerId': String offerId,
    'productId': String productId,
    'productName': String productName,
    'brand': String brand,
    'providerId': String providerId,
    'providerName': String providerName,
    'priceCents': int priceCents,
    'stockUnits': int stockUnits,
    'status': String status,
    'moderationStatus': String moderation,
    'updatedAt': String updatedAt,
  }) {
    return AdminOffer(
      offerId: offerId,
      productId: productId,
      productName: productName,
      brand: brand,
      model: _string(json, 'model'),
      category: _category(_string(json, 'category')),
      providerId: providerId,
      providerName: providerName,
      providerStatus: _string(json, 'providerStatus') ?? 'active',
      priceCents: priceCents,
      oldPriceCents: json['oldPriceCents'] is int ? json['oldPriceCents'] as int : null,
      stockUnits: stockUnits,
      status: offerStatusFromName(status),
      moderation: OfferModeration.fromName(moderation),
      moderationReason: _string(json, 'moderationReason'),
      moderatedAt: _date(json, 'moderatedAt'),
      imageUrl: _string(json, 'imageUrl'),
      flags: [for (final flag in _list(json['flags']).whereType<String>()) ?QualityFlag.fromWire(flag)],
      visible: json['visible'] == true,
      updatedAt: DateTime.parse(updatedAt),
    );
  }
  throw FormatException('Oferta inválida', json);
}

AdminOfferDetail adminOfferDetailFromJson(Object? json) {
  final map = _map(json);
  return AdminOfferDetail(
    offer: adminOfferFromJson(json),
    summary: _string(map, 'summary'),
    attributes: {for (final entry in _map(map['attributes']).entries) '${entry.key}': entry.value},
    images: [..._list(map['images']).whereType<String>()],
    otherOffers: [
      for (final other in _list(map['otherOffers']))
        if (other case {
          'offerId': String offerId,
          'providerName': String providerName,
          'priceCents': int priceCents,
          'status': String status,
        })
          SiblingOffer(
            offerId: offerId,
            providerName: providerName,
            priceCents: priceCents,
            stockUnits: _int(other, 'stockUnits'),
            status: offerStatusFromName(status),
            moderation: OfferModeration.fromName(_string(other, 'moderationStatus')),
          ),
    ],
  );
}

AdminOffersPage adminOffersPageFromJson(Object? json) {
  if (json case {'items': final List<Object?> items, 'total': int total, 'page': int page, 'pageSize': int pageSize}) {
    return AdminOffersPage(
      items: [for (final item in items) adminOfferFromJson(item)],
      total: total,
      page: page,
      pageSize: pageSize,
      counts: {
        for (final entry in _map(json['counts']).entries)
          if (entry.value is num) '${entry.key}': (entry.value! as num).toInt(),
      },
    );
  }
  throw FormatException('Página de ofertas inválida', json);
}

List<AdminOffer> updatedProductOffersFromJson(Object? json) {
  if (json case {'offers': final List<Object?> offers}) {
    return [for (final offer in offers) adminOfferFromJson(offer)];
  }
  throw FormatException('Producto inválido', json);
}

AdminOrderRow adminOrderRowFromJson(Object? json) {
  if (json case {'orderId': String orderId, 'providerId': String providerId, 'providerName': String providerName}) {
    return AdminOrderRow(
      order: vendorOrderFromJson(json),
      orderId: orderId,
      providerId: providerId,
      providerName: providerName,
      customerEmail: _string(json, 'customerEmail'),
      paymentMethod: _string(json, 'paymentMethod'),
    );
  }
  throw FormatException('Pedido inválido', json);
}

AdminOrderDetail adminOrderDetailFromJson(Object? json) {
  if (json case {
    'id': String id,
    'number': String number,
    'createdAt': String createdAt,
    'contact': final Map<Object?, Object?> contact,
    'shippingAddress': final Map<Object?, Object?> address,
    'payment': final Map<Object?, Object?> payment,
    'subOrders': final List<Object?> subOrders,
    'notes': final List<Object?> notes,
  }) {
    return AdminOrderDetail(
      id: id,
      number: number,
      createdAt: DateTime.parse(createdAt),
      totalCents: _int(json, 'totalCents'),
      contact: CustomerContact(
        fullName: _string(contact, 'fullName') ?? '',
        email: _string(contact, 'email') ?? '',
        phone: _string(contact, 'phone') ?? '',
        documentType: _string(contact, 'documentType') ?? '',
        documentNumber: _string(contact, 'documentNumber') ?? '',
      ),
      shippingAddress: ShippingAddress(
        recipientName: _string(address, 'recipientName') ?? '',
        phone: _string(address, 'phone') ?? '',
        department: _string(address, 'department') ?? '',
        city: _string(address, 'city') ?? '',
        addressLine: _string(address, 'addressLine') ?? '',
        details: _string(address, 'details'),
      ),
      payment: PaymentInfo(
        reference: _string(payment, 'reference') ?? '',
        status: _string(payment, 'status') ?? '',
        amountCents: _int(payment, 'amountCents'),
        method: _string(payment, 'method'),
        transactionId: _string(payment, 'transactionId'),
        approvedAt: _date(payment, 'approvedAt'),
      ),
      subOrders: [
        for (final sub in subOrders)
          if (sub case {'providerId': String providerId, 'providerName': String providerName})
            AdminSubOrder(
              detail: vendorOrderDetailFromJson(sub),
              providerId: providerId,
              providerName: providerName,
              adminNextStatuses: [
                for (final name in _list(sub['adminNextStatuses']).whereType<String>())
                  VendorOrderStatus.fromName(name),
              ],
            ),
      ],
      notes: [
        for (final note in notes)
          if (note case {'id': int noteId, 'message': String message, 'createdAt': String noteAt})
            OrderNote(
              id: noteId,
              subOrderId: _string(note, 'subOrderId'),
              message: message,
              actorName: _string(note, 'actorName'),
              createdAt: DateTime.parse(noteAt),
            ),
      ],
    );
  }
  throw FormatException('Detalle de pedido inválido', json);
}
