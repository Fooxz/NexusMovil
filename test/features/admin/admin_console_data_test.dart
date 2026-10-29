import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/core/errors/app_failure.dart';
import 'package:prueba01/features/account/data/mock_directory.dart';
import 'package:prueba01/features/account/domain/account_models.dart';
import 'package:prueba01/features/admin/data/admin_console_json.dart';
import 'package:prueba01/features/admin/data/mock_admin_console_repository.dart';
import 'package:prueba01/features/admin/data/supabase_admin_console_repository.dart';
import 'package:prueba01/features/admin/domain/admin_console_models.dart';
import 'package:prueba01/features/auth/data/mock_auth_repository.dart';
import 'package:prueba01/features/catalog/domain/product.dart';
import 'package:prueba01/features/provider_portal/domain/portal_models.dart';
import 'package:prueba01/features/vendor/domain/vendor_models.dart';

/// Oferta como la devuelve `admin_get_offer` (API_CONTRATO, parte 10).
const offerJson = {
  'offerId': 'zz-ca4',
  'productId': 'zz-cp4',
  'productName': 'ZZADM SSD Completo',
  'brand': 'Marca',
  'model': null,
  'category': 'storage',
  'providerId': 'zz-ca',
  'providerName': 'ZZADM Tienda A',
  'providerStatus': 'active',
  'priceCents': 10000000,
  'oldPriceCents': null,
  'stockUnits': 8,
  'status': 'published',
  'moderationStatus': 'hidden',
  'moderationReason': 'Precio fuera de mercado',
  'moderatedAt': '2026-10-28T15:00:00+00:00',
  'imageUrl': null,
  'flags': ['price_anomaly', 'algo_nuevo'],
  'visible': false,
  'updatedAt': '2026-10-28T14:00:00+00:00',
  'summary': null,
  'attributes': {'storage_type': 'NVMe', 'capacity_gb': 1000},
  'images': ['https://img.zz.test/ssd.png'],
  'otherOffers': [
    {
      'offerId': 'zz-cb4',
      'providerName': 'ZZADM Tienda B',
      'priceCents': 40000000,
      'stockUnits': 8,
      'status': 'published',
      'moderationStatus': 'approved',
    },
  ],
};

const _subOrderJson = {
  'id': 'sub-1',
  'orderNumber': 'NX-000042',
  'createdAt': '2026-10-28T15:00:00+00:00',
  'status': 'pending',
  'units': 2,
  'subtotalCents': 60000000,
  'commissionCents': 5042017,
  'netCents': 54957983,
  'shippingAddress': {
    'recipientName': 'Clara Cliente',
    'phone': '3001234567',
    'department': 'Cesar',
    'city': 'Valledupar',
    'addressLine': 'Calle 10 # 20-30',
  },
  'contact': {'fullName': 'Clara Cliente', 'email': 'clara@zz.test'},
  'nextStatuses': ['confirmed', 'rejected'],
  'items': <Object?>[],
  'history': [
    {'fromStatus': null, 'toStatus': 'pending', 'note': 'Pago aprobado', 'createdAt': '2026-10-28T15:00:00+00:00'},
  ],
  'providerId': 'zz-ca',
  'providerName': 'ZZADM Tienda A',
  'adminNextStatuses': ['confirmed', 'rejected', 'cancelled', 'incident'],
};

const orderJson = {
  'id': 'ord-1',
  'number': 'NX-000042',
  'createdAt': '2026-10-28T15:00:00+00:00',
  'totalCents': 60000000,
  'contact': {
    'fullName': 'Clara Cliente',
    'email': 'clara@zz.test',
    'phone': '3001234567',
    'documentType': 'CC',
    'documentNumber': '1065000001',
  },
  'shippingAddress': {
    'recipientName': 'Clara Cliente',
    'phone': '3001234567',
    'department': 'Cesar',
    'city': 'Valledupar',
    'addressLine': 'Calle 10 # 20-30',
  },
  'payment': {
    'reference': 'NX-20261028-0123456789',
    'status': 'approved',
    'amountCents': 60000000,
    'method': 'CARD',
    'transactionId': 'tx-1',
    'approvedAt': '2026-10-28T15:00:00+00:00',
  },
  'subOrders': [_subOrderJson],
  'notes': [
    {'id': 1, 'subOrderId': null, 'message': 'Cliente contactado', 'actorName': 'Ada', 'createdAt': '2026-10-28T16:00:00+00:00'},
  ],
};

void main() {
  group('lectura de la parte 10', () {
    test('lee el resumen: ventas, alertas conocidas, serie y categorías', () {
      final dashboard = adminDashboardFromJson({
        'sales': {'todayCents': 80000000, 'yesterdayCents': 40000000, 'monthCommissionCents': 6722689},
        'orders': {'pending': 2, 'stale': 1, 'incident': 0},
        'users': {
          'customers': 10,
          'activeCustomers': 4,
          'providers': {'active': 3, 'pending': 1},
        },
        'catalog': {'products': 760, 'flagged': 2, 'review': 1},
        'alerts': [
          {'kind': 'offers_review', 'count': 1},
          {'kind': 'algo_nuevo', 'count': 9},
        ],
        'series': [
          {'date': '2026-10-28', 'salesCents': 80000000, 'orders': 1},
        ],
        'topCategories': [
          {'category': 'storage', 'name': 'Almacenamiento', 'salesCents': 60000000, 'units': 2},
        ],
      });

      expect(dashboard.today.growthPercent, 100);
      expect(dashboard.ordersStale, 1);
      expect(dashboard.providersIn('pending'), 1);
      expect(dashboard.products, 760);
      expect(dashboard.alerts.single.kind, AdminAlertKind.offersReview, reason: 'ignora las alertas desconocidas');
      expect(dashboard.series.single.date, DateTime(2026, 10, 28));
      expect(dashboard.topCategories.single.category, ProductCategory.storage);
    });

    test('lee la oferta con su moderación, sus alertas y las otras tiendas', () {
      final detail = adminOfferDetailFromJson(offerJson);
      expect(detail.offer.moderation, OfferModeration.hidden);
      expect(detail.offer.moderationReason, 'Precio fuera de mercado');
      expect(detail.offer.flags, [QualityFlag.priceAnomaly], reason: 'ignora las alertas desconocidas');
      expect(detail.offer.category, ProductCategory.storage);
      expect(detail.attributes['capacity_gb'], 1000);
      expect(detail.otherOffers.single.providerName, 'ZZADM Tienda B');
    });

    test('lee el pedido con el pago, cada tienda y sus estados para intervenir', () {
      final order = adminOrderDetailFromJson(orderJson);
      expect(order.payment.method, 'CARD');
      expect(order.contact.documentNumber, '1065000001');
      final sub = order.subOrders.single;
      expect(sub.providerName, 'ZZADM Tienda A');
      expect(sub.detail.order.status, VendorOrderStatus.pending);
      expect(sub.adminNextStatuses, contains(VendorOrderStatus.cancelled));
      expect(order.notes.single.message, 'Cliente contactado');
    });

    test('lee la ficha de la tienda con su historial', () {
      final overview = providerOverviewFromJson({
        'id': 'zz-ca',
        'legalName': 'ZZADM A S.A.S.',
        'displayName': 'ZZADM Tienda A',
        'taxId': '900111222-1',
        'contactEmail': 'a@zz.test',
        'status': 'blocked',
        'metrics': {'sales30dCents': 60000000, 'deliveredRate': 0.75, 'warnings': 1},
        'inventory': {'published': 3, 'hidden': 1},
        'ordersByStatus': {'pending': 1, 'delivered': 3},
        'recentOrders': [
          {..._subOrderJson, 'orderId': 'ord-1'},
        ],
        'notes': [
          {
            'id': 7,
            'kind': 'status_change',
            'message': 'Vende productos falsificados',
            'fromStatus': 'active',
            'toStatus': 'blocked',
            'actorName': 'Ada',
            'createdAt': '2026-10-28T15:00:00+00:00',
          },
        ],
      });
      expect(overview.store.status, StoreStatus.blocked);
      expect(overview.metrics.deliveredRate, 0.75);
      expect(overview.ordersByStatus[VendorOrderStatus.delivered], 3);
      expect(overview.recentOrders.single.orderId, 'ord-1');
      expect(overview.notes.single.kind, ProviderNoteKind.statusChange);
    });
  });

  group('SupabaseAdminConsoleRepository', () {
    late List<(String, Map<String, Object?>)> calls;
    late Object? response;
    late SupabaseAdminConsoleRepository repository;

    setUp(() {
      calls = [];
      repository = SupabaseAdminConsoleRepository((function, params) async {
        calls.add((function, params));
        return response;
      });
    });

    test('filtra las ofertas con cualquier alerta', () async {
      response = {'items': <Object?>[], 'total': 0, 'page': 0, 'pageSize': 20, 'counts': <String, Object?>{}};
      await repository.getOffers(search: '  ssd ', moderation: OfferModeration.review, anyFlag: true);
      expect(calls.single.$1, 'admin_list_offers');
      expect(calls.single.$2, {'search': 'ssd', 'moderation': 'review', 'flag': 'any', 'page': 0});
    });

    test('modera con el motivo sin espacios', () async {
      response = offerJson;
      await repository.moderateOffer('zz-ca4', ModerationAction.hide, reason: '  Corrige la ficha  ');
      expect(calls.single.$1, 'admin_moderate_offer');
      expect(calls.single.$2, {'offer_id': 'zz-ca4', 'action': 'hide', 'reason': 'Corrige la ficha'});
    });

    test('interviene una sub-orden con la observación y filtra pedidos por día', () async {
      response = orderJson;
      await repository.updateSubOrderStatus('sub-1', VendorOrderStatus.cancelled, note: ' Pedido duplicado ');
      expect(calls.last.$1, 'admin_update_sub_order_status');
      expect(calls.last.$2, {'id': 'sub-1', 'status': 'cancelled', 'note': 'Pedido duplicado'});

      response = {'items': <Object?>[], 'total': 0, 'page': 0, 'pageSize': 20};
      await repository.getOrders(status: VendorOrderStatus.incident, from: DateTime(2026, 10, 1), to: DateTime(2026, 10, 28));
      expect(calls.last.$2, {'status': 'incident', 'from_date': '2026-10-01', 'to_date': '2026-10-28', 'page': 0});
    });

    test('registra la nota de la tienda con su tipo', () async {
      response = null;
      await expectLater(
        repository.addProviderNote('zz-ca', ProviderNoteKind.policyViolation, ' Vende usados como nuevos '),
        throwsA(isA<AppFailure>()),
        reason: 'una respuesta vacía es inválida',
      );
      expect(calls.single.$2, {'id': 'zz-ca', 'kind': 'policy_violation', 'message': 'Vende usados como nuevos'});
    });
  });

  group('MockAdminConsoleRepository', () {
    late MockAuthRepository auth;
    late MockDirectory directory;
    late MockAdminConsoleRepository repository;

    setUp(() async {
      auth = MockAuthRepository(latency: Duration.zero);
      directory = MockDirectory();
      repository = MockAdminConsoleRepository(
        auth,
        directory,
        clock: () => DateTime(2026, 10, 28, 15),
        latency: Duration.zero,
      );
      await auth.signUp(
        fullName: 'Ada Admin',
        email: 'ada@nexus.test',
        password: 'Nexus12345',
        acceptedDocuments: MockAuthRepository.documents,
      );
    });

    test('solo el administrador usa la consola', () async {
      await expectLater(repository.getDashboard(), throwsA(isA<ForbiddenFailure>()));
    });

    test('ocultar exige el motivo y aprobar lo borra', () async {
      directory.roles[auth.currentUser!.id] = AccountRole.admin;
      await expectLater(
        repository.moderateOffer('off-b1', ModerationAction.hide),
        throwsA(isA<FieldValidationFailure>()),
      );
      final hidden = await repository.moderateOffer('off-b1', ModerationAction.hide, reason: 'Precio fuera de mercado');
      expect(hidden.offer.moderation, OfferModeration.hidden);
      expect(hidden.offer.visible, isFalse);

      final approved = await repository.moderateOffer('off-b1', ModerationAction.approve);
      expect(approved.offer.moderationReason, isNull);
      expect(approved.offer.visible, isTrue);
    });

    test('cancelar una sub-orden devuelve el stock y queda en el historial como NEXUS', () async {
      directory.roles[auth.currentUser!.id] = AccountRole.admin;
      final page = await repository.getOrders(status: VendorOrderStatus.pending, search: 'mundo');
      final row = page.items.firstWhere((row) => row.providerId == 'prov-mundopc');
      final before = (await repository.getOffers(search: 'sin datos')).items.single.stockUnits;

      await expectLater(
        repository.updateSubOrderStatus(row.order.id, VendorOrderStatus.delivered, note: 'Entregado'),
        throwsA(isA<InvalidOrderTransitionFailure>()),
      );
      final order = await repository.updateSubOrderStatus(
        row.order.id,
        VendorOrderStatus.cancelled,
        note: 'El cliente pidió cancelar',
      );
      final sub = order.subOrders.firstWhere((sub) => sub.detail.order.id == row.order.id);
      expect(sub.detail.order.status, VendorOrderStatus.cancelled);
      expect(sub.detail.history.last.note, 'NEXUS: El cliente pidió cancelar');
      final after = (await repository.getOffers(search: 'sin datos')).items.single.stockUnits;
      expect(after, before + 2);
    });

    test('el historial de la tienda incluye los cambios de estado con su motivo', () async {
      directory.roles[auth.currentUser!.id] = AccountRole.admin;
      directory.statusChanges.add((
        storeId: 'prov-mundopc',
        from: StoreStatus.active,
        to: StoreStatus.blocked,
        reason: 'Vende productos falsificados',
        at: DateTime(2026, 10, 28, 14),
      ));
      final overview = await repository.addProviderNote('prov-mundopc', ProviderNoteKind.warning, 'Tercer reclamo');
      expect(overview.notes.map((note) => note.kind), [ProviderNoteKind.warning, ProviderNoteKind.statusChange]);
      expect(overview.metrics.warnings, 1);
    });
  });
}
