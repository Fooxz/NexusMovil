import '../../../core/errors/app_failure.dart';
import '../../catalog/domain/product.dart';
import '../../provider_portal/domain/portal_models.dart';
import '../domain/vendor_models.dart';
import '../domain/vendor_repository.dart';

/// Panel de una tienda de ejemplo en memoria, con las mismas reglas que el
/// backend: transiciones de estado (RN-029), motivo obligatorio, guía para
/// enviar, devolución al stock al rechazar o cancelar y movimientos de
/// inventario.
class MockVendorRepository implements VendorRepository {
  MockVendorRepository({DateTime Function()? clock}) : _clock = clock ?? DateTime.now {
    final now = _clock();
    _items.addAll([
      _Stock('off-demo-1', 'demo-gpu', 'NVIDIA GEFORCE RTX 5070', 'NVIDIA', ProductCategory.gpu, 'TD-GPU-5070', 8, 3),
      _Stock('off-demo-2', 'demo-ram', 'KINGSTON FURY BEAST DDR5 32GB', 'Kingston', ProductCategory.ram, 'TD-RAM-32', 2, 5),
      _Stock('off-demo-3', 'demo-ssd', 'SAMSUNG 990 EVO PLUS 1TB', 'Samsung', ProductCategory.storage, 'TD-SSD-1T', 0, 4),
    ]);
    for (final item in _items) {
      _movement(item, StockMovementKind.entry, item.units, 'Stock inicial', at: now.subtract(const Duration(days: 20)));
    }
    _orders.addAll([
      _Order('so-demo-1', 'NX-000101', now.subtract(const Duration(hours: 2)), [_Line(_items[0], 1, 289990000)]),
      _Order('so-demo-2', 'NX-000098', now.subtract(const Duration(days: 1)), [_Line(_items[1], 2, 54990000)],
          status: VendorOrderStatus.preparing),
      _Order('so-demo-3', 'NX-000090', now.subtract(const Duration(days: 6)), [_Line(_items[0], 1, 289990000)],
          status: VendorOrderStatus.delivered),
    ]);
  }

  static const _commissionRate = 0.10;
  static const _vatRate = 0.19;

  final DateTime Function() _clock;
  final _items = <_Stock>[];
  final _orders = <_Order>[];
  final _movements = <StockMovement>[];

  static const _next = <VendorOrderStatus, List<VendorOrderStatus>>{
    VendorOrderStatus.pending: [VendorOrderStatus.confirmed, VendorOrderStatus.rejected],
    VendorOrderStatus.confirmed: [VendorOrderStatus.preparing, VendorOrderStatus.cancelled, VendorOrderStatus.incident],
    VendorOrderStatus.preparing: [VendorOrderStatus.shipped, VendorOrderStatus.cancelled, VendorOrderStatus.incident],
    VendorOrderStatus.shipped: [VendorOrderStatus.delivered, VendorOrderStatus.incident],
    VendorOrderStatus.delivered: [VendorOrderStatus.returned, VendorOrderStatus.incident],
    VendorOrderStatus.incident: [
      VendorOrderStatus.confirmed,
      VendorOrderStatus.preparing,
      VendorOrderStatus.shipped,
      VendorOrderStatus.delivered,
      VendorOrderStatus.cancelled,
    ],
  };

  static const _reserving = {
    VendorOrderStatus.pending,
    VendorOrderStatus.confirmed,
    VendorOrderStatus.preparing,
    VendorOrderStatus.incident,
  };
  static const _voided = {VendorOrderStatus.rejected, VendorOrderStatus.cancelled};

  void _movement(_Stock item, StockMovementKind kind, int delta, String? reason, {DateTime? at, String? order}) {
    final before = item.units - delta;
    _movements.insert(
      0,
      StockMovement(
        id: _movements.length + 1,
        productId: item.productId,
        productName: item.name,
        kind: kind,
        quantityDelta: delta,
        stockBefore: before,
        stockAfter: item.units,
        reason: reason,
        orderNumber: order,
        actorName: kind == StockMovementKind.sale ? null : 'Tienda demo',
        createdAt: at ?? _clock(),
      ),
    );
  }

  InventoryItem _view(_Stock item) {
    var reserved = 0;
    var sold = 0;
    for (final order in _orders) {
      for (final line in order.lines.where((line) => line.item == item)) {
        if (_reserving.contains(order.status)) reserved += line.quantity;
        if (!_voided.contains(order.status)) sold += line.quantity;
      }
    }
    return InventoryItem(
      offerId: item.offerId,
      productId: item.productId,
      name: item.name,
      brand: item.brand,
      category: item.category,
      status: OfferStatus.published,
      externalSku: item.sku,
      stockUnits: item.units,
      minStock: item.minStock,
      reservedUnits: reserved,
      soldUnits: sold,
      alert: item.units == 0
          ? StockAlert.out
          : item.units <= item.minStock
          ? StockAlert.low
          : null,
    );
  }

  VendorOrder _orderView(_Order order) {
    final subtotal = order.lines.fold(0, (sum, line) => sum + line.total);
    final commission = order.lines.fold(0, (sum, line) => sum + line.commission);
    return VendorOrder(
      id: order.id,
      orderNumber: order.number,
      createdAt: order.createdAt,
      status: order.status,
      units: order.lines.fold(0, (sum, line) => sum + line.quantity),
      subtotalCents: subtotal,
      commissionCents: commission,
      netCents: subtotal - commission,
      customerName: 'Carlos Cliente',
      city: 'Valledupar',
      department: 'Cesar',
      carrier: order.carrier,
      trackingNumber: order.tracking,
    );
  }

  VendorOrderDetail _detail(_Order order) => VendorOrderDetail(
    order: _orderView(order),
    statusNote: order.note,
    shippingAddress: const ShippingAddress(
      recipientName: 'Carlos Cliente',
      phone: '3001234567',
      department: 'Cesar',
      city: 'Valledupar',
      addressLine: 'Calle 10 # 20-30',
    ),
    contact: const CustomerContact(
      fullName: 'Carlos Cliente',
      email: 'carlos@correo.co',
      phone: '3001234567',
      documentType: 'CC',
      documentNumber: '1065000000',
    ),
    nextStatuses: _next[order.status] ?? const [],
    items: [
      for (final line in order.lines)
        VendorOrderItem(
          productId: line.item.productId,
          productName: line.item.name,
          brand: line.item.brand,
          quantity: line.quantity,
          unitPriceCents: line.unitPrice,
          lineTotalCents: line.total,
          commissionCents: line.commission,
          netCents: line.total - line.commission,
        ),
    ],
    history: List.unmodifiable(order.history),
  );

  _Order _order(String id) =>
      _orders.firstWhere((order) => order.id == id, orElse: () => throw const NotFoundFailure());

  _Stock _item(String productId) =>
      _items.firstWhere((item) => item.productId == productId, orElse: () => throw const NotFoundFailure());

  @override
  Future<VendorDashboard> getDashboard() async {
    final now = _clock();
    final dayStart = DateTime(now.year, now.month, now.day);
    final weekStart = dayStart.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month);
    final counted = _orders.where((order) => !_voided.contains(order.status)).map(_orderView).toList();
    int sales(DateTime from, [DateTime? to]) => counted
        .where((order) => !order.createdAt.isBefore(from) && (to == null || order.createdAt.isBefore(to)))
        .fold(0, (sum, order) => sum + order.subtotalCents);
    final month = counted.where((order) => !order.createdAt.isBefore(monthStart));
    final inventory = [for (final item in _items) _view(item)];

    return VendorDashboard(
      today: SalesPeriod(sales(dayStart), sales(dayStart.subtract(const Duration(days: 1)), now.subtract(const Duration(days: 1)))),
      week: SalesPeriod(sales(weekStart), sales(weekStart.subtract(const Duration(days: 7)), now.subtract(const Duration(days: 7)))),
      month: SalesPeriod(sales(monthStart), 0),
      orderCounts: {
        for (final status in VendorOrderStatus.values)
          if (status != VendorOrderStatus.rejected)
            status: _orders
                .where((order) => status == VendorOrderStatus.cancelled
                    ? _voided.contains(order.status)
                    : order.status == status)
                .length,
      },
      activeOffers: inventory.length,
      lowStock: inventory.where((item) => item.alert == StockAlert.low).length,
      outOfStock: inventory.where((item) => item.alert == StockAlert.out).length,
      lowStockItems: inventory.where((item) => item.alert != null).toList(),
      grossCents: month.fold(0, (sum, order) => sum + order.subtotalCents),
      commissionCents: month.fold(0, (sum, order) => sum + order.commissionCents),
      netCents: month.fold(0, (sum, order) => sum + order.netCents),
      pendingPayoutCents: counted.fold(0, (sum, order) => sum + order.netCents),
      recentOrders: [for (final order in _orders.take(5)) _orderView(order)],
    );
  }

  @override
  Future<PortalPage<VendorOrder>> getOrders({VendorOrderStatus? status, String search = '', int page = 0}) async {
    final query = search.trim().toLowerCase();
    final matches = [
      for (final order in _orders)
        if ((status == null || order.status == status) &&
            (query.isEmpty || order.number.toLowerCase().contains(query) || 'carlos cliente'.contains(query)))
          _orderView(order),
    ];
    return PortalPage(items: matches.skip(page * 20).take(20).toList(), total: matches.length, page: page, pageSize: 20);
  }

  @override
  Future<VendorOrderDetail> getOrder(String id) async => _detail(_order(id));

  @override
  Future<VendorOrderDetail> updateOrderStatus(
    String id,
    VendorOrderStatus status, {
    String? note,
    String? carrier,
    String? trackingNumber,
  }) async {
    final order = _order(id);
    if (!(_next[order.status] ?? const []).contains(status)) throw const InvalidOrderTransitionFailure();
    final reason = note?.trim() ?? '';
    if (status.needsNote && reason.length < 3) {
      throw const FieldValidationFailure(field: 'note', message: 'Escribe el motivo (de 3 a 300 caracteres)');
    }
    if (status.needsShipping) {
      if ((carrier?.trim().length ?? 0) < 2) {
        throw const FieldValidationFailure(field: 'carrier', message: 'Escribe la transportadora');
      }
      if ((trackingNumber?.trim().length ?? 0) < 3) {
        throw const FieldValidationFailure(field: 'trackingNumber', message: 'Escribe el número de guía');
      }
      order
        ..carrier = carrier!.trim()
        ..tracking = trackingNumber!.trim();
    }
    order.history.add(OrderStatusChange(
      fromStatus: order.status,
      toStatus: status,
      note: reason.isEmpty ? null : reason,
      actorName: 'Tienda demo',
      createdAt: _clock(),
    ));
    order
      ..status = status
      ..note = reason.isEmpty ? null : reason;
    if (_voided.contains(status)) {
      for (final line in order.lines) {
        line.item.units += line.quantity;
        _movement(line.item, StockMovementKind.cancellation, line.quantity, 'Pedido ${order.number} ${status.label.toLowerCase()}',
            order: order.number);
      }
    }
    return _detail(order);
  }

  @override
  Future<InventoryPage> getInventory({StockAlert? alert, String search = '', int page = 0}) async {
    final all = [for (final item in _items) _view(item)];
    final query = search.trim().toLowerCase();
    final matches = all
        .where((item) => (alert == null || item.alert == alert) &&
            (query.isEmpty || item.name.toLowerCase().contains(query) || item.externalSku.toLowerCase().contains(query)))
        .toList()
      ..sort((a, b) => (a.stockUnits - a.minStock).compareTo(b.stockUnits - b.minStock));
    return InventoryPage(
      items: matches.skip(page * 20).take(20).toList(),
      total: matches.length,
      page: page,
      pageSize: 20,
      allCount: all.length,
      lowCount: all.where((item) => item.alert == StockAlert.low).length,
      outCount: all.where((item) => item.alert == StockAlert.out).length,
    );
  }

  @override
  Future<InventoryItem> adjustStock(String productId, StockMovementKind kind, int quantity, String reason) async {
    final item = _item(productId);
    if (!StockMovementKind.manual.contains(kind)) {
      throw const FieldValidationFailure(field: 'kind', message: 'El movimiento debe ser entrada, salida o ajuste');
    }
    if (reason.trim().length < 3) {
      throw const FieldValidationFailure(field: 'reason', message: 'Escribe el motivo (de 3 a 200 caracteres)');
    }
    if (quantity < 0 || (kind != StockMovementKind.adjustment && quantity == 0)) {
      throw const FieldValidationFailure(field: 'quantity', message: 'La cantidad debe ser un número entero de 1 a 100000');
    }
    final next = switch (kind) {
      StockMovementKind.entry => item.units + quantity,
      StockMovementKind.exit => item.units - quantity,
      _ => quantity,
    };
    if (next < 0) {
      throw FieldValidationFailure(field: 'quantity', message: 'Solo hay ${item.units} unidades: no puedes sacar $quantity');
    }
    if (next == item.units) {
      throw const FieldValidationFailure(field: 'quantity', message: 'El stock ya es ese: no hay nada que ajustar');
    }
    final delta = next - item.units;
    item.units = next;
    _movement(item, kind, delta, reason.trim());
    return _view(item);
  }

  @override
  Future<InventoryItem> setMinStock(String productId, int minStock) async {
    if (minStock < 0) {
      throw const FieldValidationFailure(field: 'minStock', message: 'El stock mínimo debe ser un número entero de 0 a 100000');
    }
    final item = _item(productId)..minStock = minStock;
    return _view(item);
  }

  @override
  Future<PortalPage<StockMovement>> getMovements({String? productId, int page = 0}) async {
    final matches = _movements.where((m) => productId == null || m.productId == productId).toList();
    return PortalPage(items: matches.skip(page * 30).take(30).toList(), total: matches.length, page: page, pageSize: 30);
  }
}

class _Stock {
  _Stock(this.offerId, this.productId, this.name, this.brand, this.category, this.sku, this.units, this.minStock);

  final String offerId;
  final String productId;
  final String name;
  final String brand;
  final ProductCategory category;
  final String sku;
  int units;
  int minStock;
}

class _Line {
  _Line(this.item, this.quantity, this.unitPrice);

  final _Stock item;
  final int quantity;
  final int unitPrice;

  int get total => unitPrice * quantity;

  int get commission =>
      ((total / (1 + MockVendorRepository._vatRate) * MockVendorRepository._commissionRate) / 100).round() * 100;
}

class _Order {
  _Order(this.id, this.number, this.createdAt, this.lines, {this.status = VendorOrderStatus.pending})
    : history = [
        OrderStatusChange(toStatus: VendorOrderStatus.pending, note: 'Pago aprobado', createdAt: createdAt),
        if (status != VendorOrderStatus.pending)
          OrderStatusChange(fromStatus: VendorOrderStatus.pending, toStatus: status, createdAt: createdAt),
      ];

  final String id;
  final String number;
  final DateTime createdAt;
  final List<_Line> lines;
  final List<OrderStatusChange> history;
  VendorOrderStatus status;
  String? note;
  String? carrier;
  String? tracking;
}
