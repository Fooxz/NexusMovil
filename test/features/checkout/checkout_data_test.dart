import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/core/errors/app_failure.dart';
import 'package:prueba01/features/checkout/data/checkout_json.dart';
import 'package:prueba01/features/checkout/data/supabase_checkout_repository.dart';
import 'package:prueba01/features/checkout/domain/checkout_models.dart';
import 'package:prueba01/features/checkout/presentation/payment_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Respuesta de `checkout` con la acción `status` y la orden aprobada, como la
/// devuelve el backend (API_CONTRATO, parte 5).
const approvedJson = {
  'reference': 'NX-20261024-733D2C28F6',
  'status': 'approved',
  'amountCents': 313990000,
  'currency': 'COP',
  'transactionId': '1234-1-00001',
  'paymentMethod': 'CARD',
  'message': null,
  'expiresAt': '2026-10-25T00:41:55.756115+00:00',
  'order': {
    'id': 'df3759c9',
    'number': 'NX-000005',
    'status': 'paid',
    'totalCents': 313990000,
    'createdAt': '2026-10-24T23:41:55.846419+00:00',
    'subOrders': [
      {
        'id': 'aa2ac493',
        'providerName': 'Mundo PC',
        'status': 'pending',
        'subtotalCents': 313990000,
        'items': [
          {
            'productId': 'corsair-rm850x',
            'productName': 'CORSAIR RM850x',
            'brand': 'Corsair',
            'quantity': 1,
            'unitPriceCents': 64990000,
            'lineTotalCents': 64990000,
            'backorderedUnits': 1,
          },
        ],
      },
    ],
  },
};

const contact = CheckoutContact(
  fullName: ' Ana Pérez ',
  email: 'ana@correo.co',
  phone: '3001234567',
  documentType: DocumentType.cc,
  documentNumber: '1065123456',
);

void main() {
  group('regreso de Mercado Pago', () {
    test('lee el id del pago de la página de regreso', () {
      Uri back(String query) => Uri.parse('https://nexus.test/functions/v1/checkout?$query');
      expect(paymentIdFrom(back('collection_id=1&payment_id=1234567890&status=approved')), '1234567890');
      expect(paymentIdFrom(back('collection_id=77&status=approved')), '77', reason: 'cuentas antiguas');
      expect(paymentIdFrom(back('payment_id=null&status=null')), isNull, reason: 'cerró sin pagar');
      expect(paymentIdFrom(back('')), isNull);
    });
  });

  group('checkout_json', () {
    test('reads the approved status with its order', () {
      final status = checkoutStatusFromJson(approvedJson);

      expect(status.status, PaymentStatus.approved);
      expect(status.transactionId, '1234-1-00001');
      final order = status.order!;
      expect(order.number, 'NX-000005');
      expect(order.subOrders.single.providerName, 'Mundo PC');
      expect(order.subOrders.single.items.single.lineTotalCents, 64990000);
      expect(order.hasBackorders, isTrue);
    });

    test('reads a pending status without order', () {
      final status = checkoutStatusFromJson({
        'reference': 'NX-1',
        'status': 'pending',
        'amountCents': 100,
        'transactionId': null,
        'order': null,
      });
      expect(status.status, PaymentStatus.pending);
      expect(status.order, isNull);
      expect(status.transactionId, isNull);
    });

    test('rejects unknown statuses and incomplete sessions', () {
      expect(
        () => checkoutStatusFromJson({'reference': 'x', 'status': 'raro', 'amountCents': 1}),
        throwsFormatException,
      );
      expect(() => checkoutSessionFromJson({'reference': 'x'}), throwsFormatException);
    });

    test('the session recognizes its return page, ignoring the query', () {
      final session = checkoutSessionFromJson({
        'reference': 'NX-1',
        'amountCents': 100,
        'checkoutUrl': 'https://www.mercadopago.com.co/checkout/v1/redirect?pref_id=1',
        'redirectUrl': 'http://127.0.0.1:54321/functions/v1/checkout',
        'expiresAt': '2026-10-25T00:41:55+00:00',
      });
      expect(
        session.isReturnUrl(Uri.parse('http://127.0.0.1:54321/functions/v1/checkout?id=1-2&env=test')),
        isTrue,
      );
      expect(session.isReturnUrl(Uri.parse('https://www.mercadopago.com.co/checkout/v1/redirect')), isFalse);
    });
  });

  group('SupabaseCheckoutRepository', () {
    test('start sends the address, the contact and the expected total', () async {
      Map<String, Object?>? sent;
      final repository = SupabaseCheckoutRepository((name, body) async {
        expect(name, 'checkout');
        sent = body;
        return {
          'reference': 'NX-1',
          'amountCents': 100,
          'checkoutUrl': 'https://www.mercadopago.com.co/checkout/v1/redirect?pref_id=1',
          'redirectUrl': 'https://nexus.test/vuelta',
          'expiresAt': '2026-10-25T00:41:55+00:00',
        };
      });

      final session = await repository.start(
        addressId: 'addr-1',
        contact: contact,
        expectedTotalCents: 100,
      );

      expect(session.reference, 'NX-1');
      expect(sent, {
        'action': 'start',
        'addressId': 'addr-1',
        'contact': {
          'fullName': 'Ana Pérez',
          'email': 'ana@correo.co',
          'phone': '3001234567',
          'documentType': 'CC',
          'documentNumber': '1065123456',
        },
        'expectedTotalCents': 100,
      });
    });

    test('status omits the transaction when there is none', () async {
      Map<String, Object?>? sent;
      final repository = SupabaseCheckoutRepository((name, body) async {
        sent = body;
        return approvedJson;
      });

      await repository.status('NX-1');

      expect(sent, {'action': 'status', 'reference': 'NX-1'});
    });

    test('maps PRICE_CHANGED with the new total', () async {
      final repository = SupabaseCheckoutRepository((name, body) async {
        throw const FunctionException(
          status: 409,
          details: {
            'code': 'PRICE_CHANGED',
            'message': 'El total cambió',
            'details': '{"totalCents" : 200}',
          },
        );
      });

      await expectLater(
        repository.start(addressId: 'a', contact: contact, expectedTotalCents: 100),
        throwsA(isA<PriceChangedFailure>().having((f) => f.totalCents, 'totalCents', 200)),
      );
    });

    test('maps an unconfigured gateway to PaymentsUnavailableFailure', () async {
      final repository = SupabaseCheckoutRepository((name, body) async {
        throw const FunctionException(
          status: 503,
          details: {'code': 'PAYMENTS_UNAVAILABLE', 'message': 'No disponible'},
        );
      });

      await expectLater(
        repository.start(addressId: 'a', contact: contact, expectedTotalCents: 100),
        throwsA(isA<PaymentsUnavailableFailure>()),
      );
    });
  });
}
