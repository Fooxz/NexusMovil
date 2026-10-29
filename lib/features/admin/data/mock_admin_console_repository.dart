import '../../../core/errors/app_failure.dart';
import '../../account/data/mock_directory.dart';
import '../../account/domain/account_models.dart';
import '../../auth/data/mock_auth_repository.dart';
import '../../catalog/domain/product.dart';
import '../../provider_portal/domain/portal_models.dart';
import '../../vendor/domain/vendor_models.dart';
import '../domain/admin_console_models.dart';
import '../domain/admin_console_repository.dart';
import '../domain/admin_models.dart';

class _Offer {
  _Offer(
    this.id,
    this.productId,
    this.name,
    this.brand,
    this.category,
    this.providerId,
    this.priceCents,
    this.stock, {
    this.flags = const [],
  });

  final String id;
  final String productId;
  String name;
  String brand;
  String model = '';
  ProductCategory category;
  final String providerId;
  final int priceCents;
  int stock;
  Map<String, Object?> attributes = const {};
  List<QualityFlag> flags;
  String? summary;
  var moderation = OfferModeration.approved;
  String? reason;
  DateTime? moderatedAt;
  DateTime updatedAt = DateTime(2026, 10);
}

class _Line {
  _Line(this.offer, this.quantity);

  final _Offer offer;
  final int quantity;

  int get total => offer.priceCents * quantity;

  /// 10 % sobre la base sin IVA (19 %), como la regla por defecto.
  int get commission => (total / 1.19 * 0.10).round();
}

class _Sub {
  _Sub(this.id, this.providerId, this.lines, this.status);

  final String id;
  final String providerId;
  final List<_Line> lines;
  VendorOrderStatus status;
  String? note;
  String? carrier;
  String? tracking;
  final history = <OrderStatusChange>[];
}

class _Order {
  _Order(this.id, this.number, this.createdAt, this.subs);

  final String id;
  final String number;
  final DateTime createdAt;
  final List<_Sub> subs;
  final notes = <OrderNote>[];
}

/// Consola del administrador en memoria, con las reglas de las RPC de la
/// parte 10: solo administradores, motivo para ocultar o rechazar, ficha
/// validada contra la plantilla, transiciones del administrador con
/// observación obligatoria y devolución al stock al cancelar. Las tiendas son
/// las del [MockDirectory]; las ofertas y los pedidos son de ejemplo.
class MockAdminConsoleRepository implements AdminConsoleRepository {
  MockAdminConsoleRepository(
    this._auth,
    this._directory, {
    DateTime Function()? clock,
    this.latency = const Duration(milliseconds: 200),
  }) : _clock = clock ?? DateTime.now {
    _seed();
  }

  final MockAuthRepository _auth;
  final MockDirectory _directory;
  final DateTime Function() _clock;
  final Duration latency;

  final _offers = <_Offer>[];
  final _orders = <_Order>[];
  final _notes = <String, List<ProviderNote>>{};
  var _nextNote = 1;

  static const _adminNext = <VendorOrderStatus, List<VendorOrderStatus>>{
    VendorOrderStatus.pending: [
      VendorOrderStatus.confirmed,
      VendorOrderStatus.rejected,
      VendorOrderStatus.cancelled,
      VendorOrderStatus.incident,
    ],
    VendorOrderStatus.confirmed: [VendorOrderStatus.preparing, VendorOrderStatus.cancelled, VendorOrderStatus.incident],
    VendorOrderStatus.preparing: [VendorOrderStatus.shipped, VendorOrderStatus.cancelled, VendorOrderStatus.incident],
    VendorOrderStatus.shipped: [VendorOrderStatus.delivered, VendorOrderStatus.cancelled, VendorOrderStatus.incident],
    VendorOrderStatus.delivered: [VendorOrderStatus.returned, VendorOrderStatus.incident],
    VendorOrderStatus.incident: [
      VendorOrderStatus.confirmed,
      VendorOrderStatus.preparing,
      VendorOrderStatus.shipped,
      VendorOrderStatus.delivered,
      VendorOrderStatus.cancelled,
      VendorOrderStatus.returned,
    ],
  };

  static const _voided = {VendorOrderStatus.rejected, VendorOrderStatus.cancelled};
  static const _closed = {
    VendorOrderStatus.delivered,
    VendorOrderStatus.rejected,
    VendorOrderStatus.cancelled,
    VendorOrderStatus.returned,
  };

  void _seed() {
    final now = _clock();
    _offers.addAll([
      _Offer(
        'off-a1',
        'demo-gpu',
        'NVIDIA GEFORCE RTX 5070',
        'NVIDIA',
        ProductCategory.gpu,
        'prov-tecnopartes',
        289990000,
        8,
      ),
      _Offer(
        'off-a2',
        'demo-ram',
        'KINGSTON FURY BEAST DDR5 32GB',
        'Kingston',
        ProductCategory.ram,
        'prov-tecnopartes',
        54990000,
        12,
      ),
      _Offer(
        'off-b1',
        'demo-gpu',
        'NVIDIA GEFORCE RTX 5070',
        'NVIDIA',
        ProductCategory.gpu,
        'prov-mundopc',
        99990000,
        3,
        flags: [QualityFlag.priceAnomaly],
      ),
      _Offer(
        'off-b2',
        'demo-ssd',
        'SSD SIN DATOS',
        'Genérica',
        ProductCategory.storage,
        'prov-mundopc',
        19990000,
        20,
        flags: [QualityFlag.incomplete],
      ),
      _Offer(
          'off-c1',
          'demo-ram-2',
          'Kingston Fury Beast DDR5 32 GB',
          'Kingston',
          ProductCategory.ram,
          'prov-demo',
          52990000,
          6,
          flags: [QualityFlag.duplicate],
        )
        ..moderation = OfferModeration.review
        ..reason = 'Parece duplicada de otra ficha: usa la ficha existente.',
    ]);
    for (final offer in _offers) {
      offer.updatedAt = now.subtract(const Duration(days: 2));
    }

    var number = 120;
    _Order order(Duration ago, List<_Sub> subs) {
      final created = now.subtract(ago);
      final result = _Order('ord-${number - 99}', 'NX-000${number++}', created, subs);
      for (final sub in subs) {
        sub.history.add(
          OrderStatusChange(toStatus: VendorOrderStatus.pending, note: 'Pago aprobado', createdAt: created),
        );
        if (sub.status != VendorOrderStatus.pending) {
          sub.history.add(
            OrderStatusChange(
              fromStatus: VendorOrderStatus.pending,
              toStatus: sub.status,
              actorName: _storeName(sub.providerId),
              createdAt: created.add(const Duration(hours: 3)),
            ),
          );
        }
      }
      return result;
    }

    // Ventas de los últimos 30 días para la serie del resumen.
    for (var i = 0; i < 18; i++) {
      final offer = _offers[i % 3];
      final status = i % 7 == 3 ? VendorOrderStatus.cancelled : VendorOrderStatus.delivered;
      _orders.add(
        order(Duration(hours: 30 + i * 38), [
          _Sub('sub-h$i', offer.providerId, [_Line(offer, 1 + i % 2)], status),
        ]),
      );
    }
    _orders.addAll([
      order(const Duration(hours: 3), [
        _Sub('sub-n1', 'prov-tecnopartes', [_Line(_offers[0], 1)], VendorOrderStatus.pending),
        _Sub('sub-n2', 'prov-mundopc', [_Line(_offers[3], 2)], VendorOrderStatus.pending),
      ]),
      order(const Duration(hours: 60), [
        _Sub('sub-s1', 'prov-mundopc', [_Line(_offers[2], 1)], VendorOrderStatus.pending),
      ]),
      order(const Duration(hours: 20), [
        _Sub('sub-i1', 'prov-tecnopartes', [_Line(_offers[1], 1)], VendorOrderStatus.incident)
          ..note = 'La transportadora no encuentra la dirección',
      ]),
    ]);
  }

  Future<void> _simulateLatency() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  void _requireAdmin() {
    final user = _auth.currentUser;
    if (user == null) throw const UnauthorizedFailure();
    if (_directory.roles[user.id] != AccountRole.admin) throw const ForbiddenFailure();
  }

  String _adminName() => _auth.currentUser?.email ?? 'Administrador';

  String _storeName(String id) => _directory.stores[id]?.displayName ?? id;

  MockStore _store(String id) => _directory.stores[id] ?? (throw const NotFoundFailure());

  AdminStore _adminStore(MockStore store) => AdminStore(
    id: store.id,
    legalName: store.legalName,
    displayName: store.displayName,
    taxId: store.taxId,
    contactEmail: store.contactEmail,
    status: store.status,
    verificationNote: store.verificationNote,
    accountEmail: store.userId == null ? null : _auth.emailOf(store.userId!),
    publishedOffers: _offers.where((offer) => offer.providerId == store.id).length,
  );

  Iterable<_Sub> _subsOf(String storeId) =>
      _orders.expand((order) => order.subs).where((sub) => sub.providerId == storeId);

  int _subtotal(_Sub sub) => sub.lines.fold(0, (sum, line) => sum + line.total);

  int _commission(_Sub sub) => sub.lines.fold(0, (sum, line) => sum + line.commission);

  _Order _orderOf(_Sub sub) => _orders.firstWhere((order) => order.subs.contains(sub));

  ProviderMetrics _metrics(String storeId) {
    final since = _clock().subtract(const Duration(days: 30));
    final subs = _subsOf(storeId).toList();
    final recent = subs.where((sub) => !_voided.contains(sub.status) && _orderOf(sub).createdAt.isAfter(since));
    final closed = subs.where((sub) => _closed.contains(sub.status)).length;
    return ProviderMetrics(
      sales30dCents: recent.fold(0, (sum, sub) => sum + _subtotal(sub)),
      commission30dCents: recent.fold(0, (sum, sub) => sum + _commission(sub)),
      orders: subs.length,
      openOrders: subs.where((sub) => !_closed.contains(sub.status)).length,
      incidents: subs.where((sub) => sub.status == VendorOrderStatus.incident).length,
      deliveredRate: closed == 0
          ? null
          : subs.where((sub) => sub.status == VendorOrderStatus.delivered).length / closed,
      cancelRate: closed == 0 ? null : subs.where((sub) => _voided.contains(sub.status)).length / closed,
      warnings: (_notes[storeId] ?? const [])
          .where((note) => note.kind != ProviderNoteKind.note && note.kind != ProviderNoteKind.statusChange)
          .length,
    );
  }

  VendorOrder _orderView(_Order order, _Sub sub) {
    final subtotal = _subtotal(sub);
    final commission = _commission(sub);
    return VendorOrder(
      id: sub.id,
      orderNumber: order.number,
      createdAt: order.createdAt,
      status: sub.status,
      units: sub.lines.fold(0, (sum, line) => sum + line.quantity),
      subtotalCents: subtotal,
      commissionCents: commission,
      netCents: subtotal - commission,
      customerName: 'Carlos Cliente',
      city: 'Valledupar',
      department: 'Cesar',
      carrier: sub.carrier,
      trackingNumber: sub.tracking,
    );
  }

  static const _address = ShippingAddress(
    recipientName: 'Carlos Cliente',
    phone: '3001234567',
    department: 'Cesar',
    city: 'Valledupar',
    addressLine: 'Calle 10 # 20-30',
  );
  static const _contact = CustomerContact(
    fullName: 'Carlos Cliente',
    email: 'carlos@example.com',
    phone: '3001234567',
    documentType: 'CC',
    documentNumber: '1065000000',
  );

  AdminOrderDetail _orderDetail(_Order order) => AdminOrderDetail(
    id: order.id,
    number: order.number,
    createdAt: order.createdAt,
    totalCents: order.subs.fold(0, (sum, sub) => sum + _subtotal(sub)),
    contact: _contact,
    shippingAddress: _address,
    payment: PaymentInfo(
      reference: 'NX-20261028-${order.id.hashCode.toRadixString(16).toUpperCase().padLeft(10, '0').substring(0, 10)}',
      status: 'approved',
      amountCents: order.subs.fold(0, (sum, sub) => sum + _subtotal(sub)),
      method: 'CARD',
      approvedAt: order.createdAt,
    ),
    subOrders: [
      for (final sub in order.subs)
        AdminSubOrder(
          detail: VendorOrderDetail(
            order: _orderView(order, sub),
            statusNote: sub.note,
            shippingAddress: _address,
            contact: _contact,
            nextStatuses: const [],
            items: [
              for (final line in sub.lines)
                VendorOrderItem(
                  productId: line.offer.productId,
                  productName: line.offer.name,
                  brand: line.offer.brand,
                  quantity: line.quantity,
                  unitPriceCents: line.offer.priceCents,
                  lineTotalCents: line.total,
                  commissionCents: line.commission,
                  netCents: line.total - line.commission,
                ),
            ],
            history: List.of(sub.history),
          ),
          providerId: sub.providerId,
          providerName: _storeName(sub.providerId),
          adminNextStatuses: _adminNext[sub.status] ?? const [],
        ),
    ],
    notes: List.of(order.notes),
  );

  AdminOffer _offerView(_Offer offer) {
    final store = _directory.stores[offer.providerId];
    final active = store?.status == StoreStatus.active;
    return AdminOffer(
      offerId: offer.id,
      productId: offer.productId,
      productName: offer.name,
      brand: offer.brand,
      model: offer.model.isEmpty ? null : offer.model,
      category: offer.category,
      providerId: offer.providerId,
      providerName: _storeName(offer.providerId),
      providerStatus: store?.status.name ?? 'active',
      priceCents: offer.priceCents,
      stockUnits: offer.stock,
      status: OfferStatus.published,
      moderation: offer.moderation,
      moderationReason: offer.reason,
      moderatedAt: offer.moderatedAt,
      flags: offer.flags,
      visible: active && offer.moderation == OfferModeration.approved,
      updatedAt: offer.updatedAt,
    );
  }

  AdminOfferDetail _offerDetail(_Offer offer) => AdminOfferDetail(
    offer: _offerView(offer),
    summary: offer.summary,
    attributes: offer.attributes,
    otherOffers: [
      for (final other in _offers)
        if (other.productId == offer.productId && other.id != offer.id)
          SiblingOffer(
            offerId: other.id,
            providerName: _storeName(other.providerId),
            priceCents: other.priceCents,
            stockUnits: other.stock,
            status: OfferStatus.published,
            moderation: other.moderation,
          ),
    ],
  );

  _Offer _offer(String id) =>
      _offers.firstWhere((offer) => offer.id == id, orElse: () => throw const NotFoundFailure());

  @override
  Future<AdminDashboard> getDashboard() async {
    await _simulateLatency();
    _requireAdmin();
    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);
    final week = today.subtract(Duration(days: today.weekday - 1));
    final month = DateTime(now.year, now.month);
    final valid = [
      for (final order in _orders)
        for (final sub in order.subs)
          if (!_voided.contains(sub.status)) (at: order.createdAt, sub: sub),
    ];
    int salesBetween(DateTime from, DateTime to) => valid
        .where((row) => !row.at.isBefore(from) && row.at.isBefore(to))
        .fold(0, (sum, row) => sum + _subtotal(row.sub));
    final subs = _orders.expand((order) => order.subs).toList();
    int count(bool Function(_Sub) test) => subs.where(test).length;
    final monthRows = valid.where((row) => !row.at.isBefore(month));
    final providers = <String, int>{};
    for (final store in _directory.stores.values) {
      providers.update(store.status.name, (n) => n + 1, ifAbsent: () => 1);
    }
    final stale = count(
      (sub) =>
          sub.status == VendorOrderStatus.pending &&
          _orderOf(sub).createdAt.isBefore(now.subtract(const Duration(hours: 48))),
    );
    final review = _offers.where((offer) => offer.moderation == OfferModeration.review).length;
    final incidents = count((sub) => sub.status == VendorOrderStatus.incident);
    final byCategory = <ProductCategory, ({int sales, int units})>{};
    for (final row in valid.where((row) => row.at.isAfter(now.subtract(const Duration(days: 30))))) {
      for (final line in row.sub.lines) {
        final current = byCategory[line.offer.category] ?? (sales: 0, units: 0);
        byCategory[line.offer.category] = (sales: current.sales + line.total, units: current.units + line.quantity);
      }
    }
    return AdminDashboard(
      totalSalesCents: valid.fold(0, (sum, row) => sum + _subtotal(row.sub)),
      totalCommissionCents: valid.fold(0, (sum, row) => sum + _commission(row.sub)),
      today: SalesPeriod(
        salesBetween(today, now),
        salesBetween(today.subtract(const Duration(days: 1)), now.subtract(const Duration(days: 1))),
      ),
      week: SalesPeriod(
        salesBetween(week, now),
        salesBetween(week.subtract(const Duration(days: 7)), now.subtract(const Duration(days: 7))),
      ),
      month: SalesPeriod(
        salesBetween(month, now),
        salesBetween(
          DateTime(now.year, now.month - 1),
          DateTime(now.year, now.month - 1, now.day, now.hour, now.minute),
        ),
      ),
      monthCommissionCents: monthRows.fold(0, (sum, row) => sum + _commission(row.sub)),
      monthProviderNetCents: monthRows.fold(0, (sum, row) => sum + _subtotal(row.sub) - _commission(row.sub)),
      totalOrders: _orders.length,
      ordersInProgress: count((sub) => !_closed.contains(sub.status) && sub.status != VendorOrderStatus.incident),
      ordersPending: count((sub) => sub.status == VendorOrderStatus.pending),
      ordersDelivered: count((sub) => sub.status == VendorOrderStatus.delivered),
      ordersCancelled: count((sub) => _voided.contains(sub.status)),
      ordersReturned: count((sub) => sub.status == VendorOrderStatus.returned),
      ordersIncident: incidents,
      ordersStale: stale,
      customers: 42,
      activeCustomers: 17,
      newCustomers: 9,
      providersByStatus: providers,
      products: _offers.map((offer) => offer.productId).toSet().length,
      visibleProducts: _offers
          .where((offer) => _offerView(offer).visible)
          .map((offer) => offer.productId)
          .toSet()
          .length,
      outOfStockProducts: 0,
      offers: _offers.length,
      hiddenOffers: _offers.where((offer) => offer.moderation == OfferModeration.hidden).length,
      reviewOffers: review,
      rejectedOffers: _offers.where((offer) => offer.moderation == OfferModeration.rejected).length,
      flaggedOffers: _offers
          .where((offer) => offer.moderation == OfferModeration.approved && offer.flags.isNotEmpty)
          .length,
      alerts: [
        if (review > 0) AdminAlert(AdminAlertKind.offersReview, review),
        if (incidents > 0) AdminAlert(AdminAlertKind.ordersIncident, incidents),
        if (stale > 0) AdminAlert(AdminAlertKind.ordersStale, stale),
      ],
      series: [
        for (var day = 29; day >= 0; day--)
          () {
            final start = today.subtract(Duration(days: day));
            final end = start.add(const Duration(days: 1));
            final rows = valid.where((row) => !row.at.isBefore(start) && row.at.isBefore(end));
            return DailyPoint(
              date: start,
              salesCents: rows.fold(0, (sum, row) => sum + _subtotal(row.sub)),
              commissionCents: rows.fold(0, (sum, row) => sum + _commission(row.sub)),
              orders: rows.length,
              newCustomers: day % 4 == 0 ? 1 : 0,
              newProviders: 0,
            );
          }(),
      ],
      topCategories: [
        for (final entry in byCategory.entries.toList()..sort((a, b) => b.value.sales.compareTo(a.value.sales)))
          CategorySales(
            category: entry.key,
            name: entry.key.name,
            salesCents: entry.value.sales,
            units: entry.value.units,
          ),
      ],
    );
  }

  @override
  Future<List<AdminProviderRow>> getProviders({
    String search = '',
    StoreStatus? status,
    ProviderSort sort = ProviderSort.name,
  }) async {
    await _simulateLatency();
    _requireAdmin();
    final query = search.trim().toLowerCase();
    final rows = [
      for (final store in _directory.stores.values)
        if ((status == null || store.status == status) &&
            (query.isEmpty ||
                store.displayName.toLowerCase().contains(query) ||
                store.legalName.toLowerCase().contains(query) ||
                store.taxId.contains(query)))
          AdminProviderRow(store: _adminStore(store), metrics: _metrics(store.id)),
    ];
    int byName(AdminProviderRow a, AdminProviderRow b) =>
        a.store.displayName.toLowerCase().compareTo(b.store.displayName.toLowerCase());
    return rows..sort(switch (sort) {
      ProviderSort.sales => (a, b) {
        final bySales = b.metrics.sales30dCents.compareTo(a.metrics.sales30dCents);
        return bySales != 0 ? bySales : byName(a, b);
      },
      ProviderSort.performance => (a, b) {
        final byRate = (b.metrics.deliveredRate ?? -1).compareTo(a.metrics.deliveredRate ?? -1);
        return byRate != 0 ? byRate : byName(a, b);
      },
      // Las del mock no tienen fecha de creación: el orden de alta.
      ProviderSort.recent => (a, b) => b.store.id.compareTo(a.store.id),
      ProviderSort.name => byName,
    });
  }

  @override
  Future<ProviderOverview> getProviderOverview(String id) async {
    await _simulateLatency();
    _requireAdmin();
    return _overview(id);
  }

  ProviderOverview _overview(String id) {
    final store = _store(id);
    final subs = _subsOf(id).toList();
    final offers = _offers.where((offer) => offer.providerId == id);
    final ordersByStatus = <VendorOrderStatus, int>{};
    for (final sub in subs) {
      ordersByStatus.update(sub.status, (n) => n + 1, ifAbsent: () => 1);
    }
    final notes = [
      ...?_notes[id],
      for (final change in _directory.statusChanges.where((change) => change.storeId == id))
        ProviderNote(
          id: 0,
          kind: ProviderNoteKind.statusChange,
          message: change.reason,
          fromStatus: change.from.name,
          toStatus: change.to.name,
          actorName: _adminName(),
          createdAt: change.at,
        ),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final recent = [for (final sub in subs) (order: _orderOf(sub), sub: sub)]
      ..sort((a, b) => b.order.createdAt.compareTo(a.order.createdAt));
    return ProviderOverview(
      store: _adminStore(store),
      metrics: _metrics(id),
      inventory: ProviderInventorySummary(
        published: offers.length,
        lowStock: offers.where((offer) => offer.stock > 0 && offer.stock <= 5).length,
        outOfStock: offers.where((offer) => offer.stock == 0).length,
        hidden: offers
            .where((offer) => offer.moderation == OfferModeration.hidden || offer.moderation == OfferModeration.review)
            .length,
        rejected: offers.where((offer) => offer.moderation == OfferModeration.rejected).length,
      ),
      ordersByStatus: ordersByStatus,
      recentOrders: [for (final row in recent.take(5)) _row(row.order, row.sub)],
      notes: notes,
    );
  }

  @override
  Future<ProviderOverview> addProviderNote(String id, ProviderNoteKind kind, String message) async {
    await _simulateLatency();
    _requireAdmin();
    _store(id);
    if (!ProviderNoteKind.manual.contains(kind)) {
      throw const FieldValidationFailure(field: 'kind', message: 'Elige el tipo de registro');
    }
    final text = message.trim();
    if (text.length < 3 || text.length > 500) {
      throw const FieldValidationFailure(field: 'message', message: 'Escribe el detalle (de 3 a 500 caracteres)');
    }
    (_notes[id] ??= []).add(
      ProviderNote(id: _nextNote++, kind: kind, message: text, actorName: _adminName(), createdAt: _clock()),
    );
    return _overview(id);
  }

  @override
  Future<AdminOffersPage> getOffers({
    String search = '',
    String? providerId,
    ProductCategory? category,
    OfferModeration? moderation,
    QualityFlag? flag,
    bool anyFlag = false,
    int page = 0,
  }) async {
    await _simulateLatency();
    _requireAdmin();
    const pageSize = 20;
    final query = search.trim().toLowerCase();
    final filtered = _offers.where(
      (offer) =>
          (providerId == null || offer.providerId == providerId) &&
          (category == null || offer.category == category) &&
          (query.isEmpty ||
              offer.name.toLowerCase().contains(query) ||
              offer.brand.toLowerCase().contains(query) ||
              _storeName(offer.providerId).toLowerCase().contains(query)),
    );
    final matched =
        filtered
            .where(
              (offer) =>
                  (moderation == null || offer.moderation == moderation) &&
                  (anyFlag ? offer.flags.isNotEmpty : flag == null || offer.flags.contains(flag)),
            )
            .toList()
          ..sort((a, b) {
            final byReview = (b.moderation == OfferModeration.review ? 1 : 0).compareTo(
              a.moderation == OfferModeration.review ? 1 : 0,
            );
            return byReview != 0 ? byReview : b.flags.length.compareTo(a.flags.length);
          });
    int count(OfferModeration value) => filtered.where((offer) => offer.moderation == value).length;
    return AdminOffersPage(
      items: [for (final offer in matched.skip(page * pageSize).take(pageSize)) _offerView(offer)],
      total: matched.length,
      page: page,
      pageSize: pageSize,
      counts: {
        'all': filtered.length,
        for (final value in OfferModeration.values) value.name: count(value),
        'flagged': filtered.where((offer) => offer.flags.isNotEmpty).length,
      },
    );
  }

  @override
  Future<AdminOfferDetail> getOffer(String offerId) async {
    await _simulateLatency();
    _requireAdmin();
    return _offerDetail(_offer(offerId));
  }

  @override
  Future<AdminOfferDetail> moderateOffer(String offerId, ModerationAction action, {String? reason}) async {
    await _simulateLatency();
    _requireAdmin();
    final offer = _offer(offerId);
    final text = reason?.trim() ?? '';
    if (action != ModerationAction.approve && (text.length < 3 || text.length > 300)) {
      throw const FieldValidationFailure(
        field: 'reason',
        message: 'Escribe el motivo para la tienda (de 3 a 300 caracteres)',
      );
    }
    offer
      ..moderation = switch (action) {
        ModerationAction.approve => OfferModeration.approved,
        ModerationAction.hide => OfferModeration.hidden,
        ModerationAction.reject => OfferModeration.rejected,
      }
      ..reason = action == ModerationAction.approve ? null : text
      ..moderatedAt = _clock();
    return _offerDetail(offer);
  }

  @override
  Future<List<AdminOffer>> updateProduct(String productId, AdminProductInput product) async {
    await _simulateLatency();
    _requireAdmin();
    final offers = _offers.where((offer) => offer.productId == productId).toList();
    if (offers.isEmpty) throw const NotFoundFailure();
    if (product.name.trim().length < 3) {
      throw const FieldValidationFailure(field: 'name', message: 'El nombre debe tener de 3 a 160 caracteres');
    }
    if (product.brand.trim().isEmpty) {
      throw const FieldValidationFailure(field: 'brand', message: 'La marca es obligatoria (hasta 60 caracteres)');
    }
    if (product.model.trim().isEmpty) {
      throw const FieldValidationFailure(field: 'model', message: 'El modelo es obligatorio (hasta 80 caracteres)');
    }
    for (final offer in offers) {
      offer
        ..name = product.name.trim()
        ..brand = product.brand.trim()
        ..model = product.model.trim()
        ..summary = product.summary
        ..category = product.category
        ..attributes = product.attributes
        ..flags = [
          for (final flag in offer.flags)
            if (flag != QualityFlag.incomplete) flag,
        ]
        ..updatedAt = _clock();
    }
    return [for (final offer in offers) _offerView(offer)];
  }

  AdminOrderRow _row(_Order order, _Sub sub) => AdminOrderRow(
    order: _orderView(order, sub),
    orderId: order.id,
    providerId: sub.providerId,
    providerName: _storeName(sub.providerId),
    customerEmail: _contact.email,
    paymentMethod: 'CARD',
  );

  @override
  Future<PortalPage<AdminOrderRow>> getOrders({
    String search = '',
    String? providerId,
    VendorOrderStatus? status,
    DateTime? from,
    DateTime? to,
    int page = 0,
  }) async {
    await _simulateLatency();
    _requireAdmin();
    const pageSize = 20;
    final query = search.trim().toLowerCase();
    final rows = [
      for (final order in _orders.reversed)
        for (final sub in order.subs)
          if ((providerId == null || sub.providerId == providerId) &&
              (status == null || sub.status == status) &&
              (from == null || !order.createdAt.isBefore(DateTime(from.year, from.month, from.day))) &&
              (to == null || order.createdAt.isBefore(DateTime(to.year, to.month, to.day + 1))) &&
              (query.isEmpty ||
                  order.number.toLowerCase().contains(query) ||
                  'carlos cliente'.contains(query) ||
                  _storeName(sub.providerId).toLowerCase().contains(query)))
            _row(order, sub),
    ]..sort((a, b) => b.order.createdAt.compareTo(a.order.createdAt));
    return PortalPage(
      items: rows.skip(page * pageSize).take(pageSize).toList(),
      total: rows.length,
      page: page,
      pageSize: pageSize,
    );
  }

  _Order _findOrder(String id) =>
      _orders.firstWhere((order) => order.id == id, orElse: () => throw const NotFoundFailure());

  @override
  Future<AdminOrderDetail> getOrder(String orderId) async {
    await _simulateLatency();
    _requireAdmin();
    return _orderDetail(_findOrder(orderId));
  }

  @override
  Future<AdminOrderDetail> updateSubOrderStatus(
    String subOrderId,
    VendorOrderStatus status, {
    required String note,
    String? carrier,
    String? trackingNumber,
  }) async {
    await _simulateLatency();
    _requireAdmin();
    final order = _orders.firstWhere(
      (order) => order.subs.any((sub) => sub.id == subOrderId),
      orElse: () => throw const NotFoundFailure(),
    );
    final sub = order.subs.firstWhere((sub) => sub.id == subOrderId);
    if (!(_adminNext[sub.status] ?? const []).contains(status)) throw const InvalidOrderTransitionFailure();
    final text = note.trim();
    if (text.length < 3 || text.length > 300) {
      throw const FieldValidationFailure(field: 'note', message: 'Escribe la observación (de 3 a 300 caracteres)');
    }
    if (status == VendorOrderStatus.shipped &&
        ((carrier ?? '').trim().isEmpty || (trackingNumber ?? '').trim().isEmpty)) {
      throw const FieldValidationFailure(
        field: 'trackingNumber',
        message: 'Escribe la transportadora y el número de guía',
      );
    }
    sub.history.add(
      OrderStatusChange(
        fromStatus: sub.status,
        toStatus: status,
        note: 'NEXUS: $text',
        actorName: _adminName(),
        createdAt: _clock(),
      ),
    );
    sub
      ..status = status
      ..note = text;
    if (status == VendorOrderStatus.shipped) {
      sub
        ..carrier = carrier!.trim()
        ..tracking = trackingNumber!.trim();
    }
    if (_voided.contains(status)) {
      for (final line in sub.lines) {
        line.offer.stock += line.quantity;
      }
    }
    return _orderDetail(order);
  }

  @override
  Future<AdminOrderDetail> addOrderNote(String orderId, String message, {String? subOrderId}) async {
    await _simulateLatency();
    _requireAdmin();
    final order = _findOrder(orderId);
    final text = message.trim();
    if (text.length < 3 || text.length > 500) {
      throw const FieldValidationFailure(field: 'message', message: 'Escribe la observación (de 3 a 500 caracteres)');
    }
    order.notes.add(
      OrderNote(
        id: order.notes.length + 1,
        subOrderId: subOrderId,
        message: text,
        actorName: _adminName(),
        createdAt: _clock(),
      ),
    );
    return _orderDetail(order);
  }
}
