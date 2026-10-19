import 'package:flutter_test/flutter_test.dart';

import 'package:prueba01/core/errors/app_failure.dart';

void main() {
  group('AppFailure.fromApiError', () {
    test('maps contract codes regardless of status', () {
      expect(
        AppFailure.fromApiError(code: 'PRODUCT_NOT_FOUND'),
        isA<NotFoundFailure>(),
      );
      expect(
        AppFailure.fromApiError(code: 'VALIDATION_ERROR'),
        isA<ValidationFailure>(),
      );
      expect(
        AppFailure.fromApiError(statusCode: 500, code: 'INTERNAL_ERROR'),
        isA<UnexpectedFailure>(),
      );
    });

    test('falls back to the HTTP status when code is unknown', () {
      expect(AppFailure.fromApiError(statusCode: 404), isA<NotFoundFailure>());
      expect(
        AppFailure.fromApiError(statusCode: 400, code: 'SOMETHING_NEW'),
        isA<ValidationFailure>(),
      );
      expect(
        AppFailure.fromApiError(statusCode: 401),
        isA<UnauthorizedFailure>(),
      );
      expect(
        AppFailure.fromApiError(statusCode: 403),
        isA<UnauthorizedFailure>(),
      );
      expect(AppFailure.fromApiError(), isA<UnexpectedFailure>());
    });

    test('exposes a Spanish user message through toString', () {
      const failure = NetworkFailure();
      expect(failure.toString(), failure.userMessage);
      expect(failure.userMessage, contains('conexión'));
    });
  });
}
