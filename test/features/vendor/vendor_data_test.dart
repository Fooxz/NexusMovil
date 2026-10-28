import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/core/errors/app_failure.dart';
import 'package:prueba01/features/vendor/data/mock_vendor_repository.dart';
import 'package:prueba01/features/vendor/data/supabase_vendor_repository.dart';
import 'package:prueba01/features/vendor/data/vendor_json.dart';
import 'package:prueba01/features/vendor/domain/vendor_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Detalle de pedido como lo devuelve `get_my_order` (API_CONTRATO, parte 9).
const orderJson = {
  'id': 'so-1',
  'orderNumber': 'NX-000042',
  'createdAt': '2026-10-28T15:00:00+00:00',
  'status': 'pending',
  'statusChangedAt': '2026-10-28T15:00:00+00:00',
  'units': 3,
  'subtotalCents': 230000000,
  'commissionCents': 18500000,
  'netCents': 211500000,
  'customerName': 'Carlos Cliente',
  'city': 'Valledupar',
  'department': 'Cesar',
  'carrier': null,
  'trackingNumber': null,
  'hasBackorders': false,
  'statusNote': null,
  'shippingAddress': {
    'label': 'Casa',
    'recipientName': 'Carlos Cliente',
    'phone': '3001234567',
    'department': 'Cesar',
    'city': 'Valledupar',
    'addressLine': 'Calle 10 # 20-30',
    'details': null,
  },
  'contact': {
    'fullName': 'Carlos Cliente',
    'email': 'carlos@zz.test',
    'phone': '3001234567',
    'documentType': 'CC',
    'documentNumber': '1065000000',
  },
  'nextStatuses': ['confirmed', 'rejected'],
  'items': [
    {
      'offerId': 'zz-va1',
      'productId': 'zz-vp1',
      'productName': 'ZZTEST GPU',
      'brand': 'Marca',
      'quantity': 2,
      'unitPriceCents': 100000000,
      'lineTotalCents': 200000000,
      'commissionCents': 16800000,
      'netCents': 183200000,
      'backorderedUnits': 0,
    },
  ],
  'history': [
    {
      'fromStatus': null,
      'toStatus': 'pending',
      'note': 'Pago aprobado',
      'actorName': null,
      'createdAt': '2026-10-28T15:00:00+00:00',
    },
  ],
};

const inventoryItemJson = {
  'offerId': 'zz-va2',
  'productId': 'zz-vp2',
  'name': 'ZZTEST RAM',
  'brand': 'Marca',
  'category': 'ram',
  'imageUrl': null,
  'status': 'published',
  'externalSku': 'A2',
  'stockUnits': 3,
  'minStock': 5,
  'reservedUnits': 1,
  'soldUnits': 1,
  'alert': 'low',
  'updatedAt': '2026-10-28T15:00:00+00:00',
};

void main() {
  group('vendor_json', () {
    test('reads the order detail with its next statuses and history', () {
      final detail = vendorOrderDetailFromJson(orderJson);

      expect(detail.order.orderNumber, 'NX-000042');
      expect(detail.order.status, VendorOrderStatus.pending);
      expect(detail.order.netCents, 211500000);
      expect(detail.nextStatuses, [VendorOrderStatus.confirmed, VendorOrderStatus.rejected]);
      expect(detail.shippingAddress.addressLine, 'Calle 10 # 20-30');
      expect(detail.contact.documentNumber, '1065000000');
      expect(detail.items.single.quantity, 2);
      expect(detail.history.single.fromStatus, isNull);
    });

    test('reads the inventory with its alert counts', () {
      final page = inventoryPageFromJson({
        'items': [inventoryItemJson],
        'total': 1,
        'page': 0,
        'pageSize': 20,
        'counts': {'all': 2, 'low': 1, 'out': 0},
      });

      expect(page.items.single.alert, StockAlert.low);
      expect(page.items.single.reservedUnits, 1);
      expect((page.allCount, page.lowCount, page.outCount), (2, 1, 0));
    });

    test('reads the dashboard and computes growth', () {
      final dashboard = vendorDashboardFromJson({
        'sales': {
          'todayCents': 30000000,
          'yesterdayCents': 20000000,
          'weekCents': 30000000,
          'previousWeekCents': 0,
          'monthCents': 230000000,
          'previousMonthCents': 115000000,
        },
        'orders': {'pending': 2, 'confirmed': 0, 'preparing': 1, 'shipped': 0, 'delivered': 4,
          'cancelled': 1, 'returned': 0, 'incident': 0},
        'inventory': {'active': 5, 'outOfStock': 1, 'lowStock': 2},
        'lowStockItems': [inventoryItemJson],
        'finance': {'grossCents': 230000000, 'commissionCents': 18500000, 'netCents': 211500000,
          'pendingPayoutCents': 211500000},
        'recentOrders': [orderJson],
      });

      expect(dashboard.today.growthPercent, 50);
      expect(dashboard.week.growthPercent, isNull, reason: 'sin ventas la semana anterior');
      expect(dashboard.month.growthPercent, 100);
      expect(dashboard.ordersIn(VendorOrderStatus.pending), 2);
      expect(dashboard.recentOrders.single.orderNumber, 'NX-000042');
    });

    test('rejects an unknown order status', () {
      expect(() => vendorOrderFromJson({...orderJson, 'status': 'lost'}), throwsFormatException);
    });
  });

  group('SupabaseVendorRepository', () {
    test('sends the status change with the shipping data', () async {
      (String, Map<String, Object?>)? sent;
      final repository = SupabaseVendorRepository((function, params) async {
        sent = (function, params);
        return orderJson;
      });

      await repository.updateOrderStatus('so-1', VendorOrderStatus.shipped,
          carrier: 'Servientrega', trackingNumber: 'SV-1');

      expect(sent!.$1, 'update_my_order_status');
      expect(sent!.$2, {
        'id': 'so-1',
        'status': 'shipped',
        'carrier': 'Servientrega',
        'tracking_number': 'SV-1',
      });
    });

    test('sends the manual stock movement', () async {
      (String, Map<String, Object?>)? sent;
      final repository = SupabaseVendorRepository((function, params) async {
        sent = (function, params);
        return inventoryItemJson;
      });

      await repository.adjustStock('zz-vp2', StockMovementKind.exit, 2, '  Muestras  ');

      expect(sent!.$1, 'adjust_my_stock');
      expect(sent!.$2, {
        'product_id': 'zz-vp2',
        'kind': 'exit',
        'quantity': 2,
        'reason': 'Muestras',
      });
    });

    test('maps a stale transition to InvalidOrderTransitionFailure', () async {
      final repository = SupabaseVendorRepository((function, params) async {
        throw const PostgrestException(message: 'No', code: 'INVALID_TRANSITION');
      });

      await expectLater(
        repository.updateOrderStatus('so-1', VendorOrderStatus.delivered),
        throwsA(isA<InvalidOrderTransitionFailure>()),
      );
    });
  });

  group('MockVendorRepository', () {
    late MockVendorRepository repository;

    setUp(() => repository = MockVendorRepository(clock: () => DateTime(2026, 10, 28, 15)));

    test('follows the order flow and asks for the shipping data', () async {
      await expectLater(
        repository.updateOrderStatus('so-demo-1', VendorOrderStatus.shipped),
        throwsA(isA<InvalidOrderTransitionFailure>()),
      );
      await repository.updateOrderStatus('so-demo-1', VendorOrderStatus.confirmed);
      await repository.updateOrderStatus('so-demo-1', VendorOrderStatus.preparing);
      await expectLater(
        repository.updateOrderStatus('so-demo-1', VendorOrderStatus.shipped),
        throwsA(isA<FieldValidationFailure>()),
      );
      final shipped = await repository.updateOrderStatus('so-demo-1', VendorOrderStatus.shipped,
          carrier: 'Coordinadora', trackingNumber: 'CO-99');

      expect(shipped.order.trackingNumber, 'CO-99');
      expect(shipped.history.map((change) => change.toStatus), [
        VendorOrderStatus.pending,
        VendorOrderStatus.confirmed,
        VendorOrderStatus.preparing,
        VendorOrderStatus.shipped,
      ]);
    });

    test('rejecting returns the units to the stock', () async {
      final before = (await repository.getInventory()).items.firstWhere((i) => i.productId == 'demo-gpu');
      await repository.updateOrderStatus('so-demo-1', VendorOrderStatus.rejected, note: 'Sin unidades');
      final after = (await repository.getInventory()).items.firstWhere((i) => i.productId == 'demo-gpu');

      expect(after.stockUnits, before.stockUnits + 1);
      expect((await repository.getMovements(productId: 'demo-gpu')).items.first.kind,
          StockMovementKind.cancellation);
    });

    test('a manual movement needs a reason and cannot go below zero', () async {
      await expectLater(
        repository.adjustStock('demo-ram', StockMovementKind.entry, 5, ''),
        throwsA(isA<FieldValidationFailure>()),
      );
      await expectLater(
        repository.adjustStock('demo-ram', StockMovementKind.exit, 50, 'Muestras'),
        throwsA(isA<FieldValidationFailure>()),
      );
      final item = await repository.adjustStock('demo-ram', StockMovementKind.entry, 5, 'Llegó mercancía');
      expect(item.stockUnits, 7);
      expect(item.alert, isNull, reason: '7 supera el mínimo de 5');
    });
  });
}
