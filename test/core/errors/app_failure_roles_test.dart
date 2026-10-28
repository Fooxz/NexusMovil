import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/core/errors/app_failure.dart';

void main() {
  group('AppFailure.fromApiError: roles y tiendas (partes 7 y 8)', () {
    test('mapea los controles de acceso', () {
      expect(AppFailure.fromApiError(code: 'FORBIDDEN'), isA<ForbiddenFailure>());
      expect(AppFailure.fromApiError(code: 'PROVIDER_REQUIRED'), isA<ForbiddenFailure>());
      expect(AppFailure.fromApiError(code: 'PROVIDER_NOT_ACTIVE'), isA<StoreNotActiveFailure>());
      expect(
        AppFailure.fromApiError(code: 'PASSWORD_CHANGE_REQUIRED'),
        isA<PasswordChangeRequiredFailure>(),
      );
      expect(AppFailure.fromApiError(code: 'CONSENT_REQUIRED'), isA<DocumentsPendingFailure>());
      expect(AppFailure.fromApiError(code: 'CUSTOMER_ONLY'), isA<CustomerOnlyFailure>());
    });

    test('PRODUCT_EXISTS informa el producto para ofertar sobre él', () {
      final failure = AppFailure.fromApiError(
        code: 'PRODUCT_EXISTS',
        details: '{"productId": "rtx-5090", "name": "NVIDIA RTX 5090"}',
      );
      expect(failure, isA<ProductExistsFailure>());
      failure as ProductExistsFailure;
      expect(failure.productId, 'rtx-5090');
      expect(failure.productName, 'NVIDIA RTX 5090');
    });

    test('POSSIBLE_DUPLICATE trae los parecidos', () {
      final failure = AppFailure.fromApiError(
        code: 'POSSIBLE_DUPLICATE',
        details: '{"candidates": [{"productId": "rtx-5090", "name": "RTX 5090", "model": "RTX 5090"}]}',
      ) as PossibleDuplicateFailure;
      expect(failure.candidates.single.productId, 'rtx-5090');
      expect(failure.candidates.single.model, 'RTX 5090');
    });

    test('SIMILAR_STORE_NAME nombra la tienda parecida', () {
      final failure = AppFailure.fromApiError(
        code: 'SIMILAR_STORE_NAME',
        details: '{"providerId": "prov-1", "displayName": "Mundo PC"}',
      );
      expect(failure.userMessage, contains('Mundo PC'));
    });

    test('un VALIDATION_ERROR con campo muestra el mensaje del backend', () {
      final failure = AppFailure.fromApiError(
        code: 'VALIDATION_ERROR',
        details: '{"field": "attributes.socket"}',
        message: 'Falta el atributo obligatorio «Socket»',
      );
      expect(failure, isA<FieldValidationFailure>());
      expect((failure as FieldValidationFailure).field, 'attributes.socket');
      expect(failure.userMessage, 'Falta el atributo obligatorio «Socket»');
    });

    test('un VALIDATION_ERROR sin campo conserva el mensaje genérico', () {
      expect(
        AppFailure.fromApiError(code: 'VALIDATION_ERROR', message: 'page no puede ser negativo'),
        isA<ValidationFailure>(),
      );
    });

    test('mapea los conflictos de publicaciones y de tiendas', () {
      expect(AppFailure.fromApiError(code: 'PRODUCT_SHARED'), isA<ProductSharedFailure>());
      expect(AppFailure.fromApiError(code: 'PRODUCT_LOCKED'), isA<ProductLockedFailure>());
      expect(AppFailure.fromApiError(code: 'OFFER_EXISTS'), isA<OfferExistsFailure>());
      expect(AppFailure.fromApiError(code: 'OFFER_RETIRED'), isA<OfferRetiredFailure>());
      expect(AppFailure.fromApiError(code: 'TAX_ID_TAKEN'), isA<TaxIdTakenFailure>());
      expect(AppFailure.fromApiError(code: 'EMAIL_EXISTS'), isA<StoreEmailTakenFailure>());
      expect(AppFailure.fromApiError(code: 'PROVIDER_HAS_ACCOUNT'), isA<StoreHasAccountFailure>());
      expect(AppFailure.fromApiError(code: 'PROVIDER_NOT_FOUND'), isA<NotFoundFailure>());
      expect(AppFailure.fromApiError(code: 'AUTH_UNAVAILABLE'), isA<AccountServiceFailure>());
    });
  });
}
