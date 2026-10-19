import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/core/errors/app_failure.dart';
import 'package:prueba01/features/auth/data/supabase_auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

void main() {
  test('maps Supabase Auth codes to AppFailure', () {
    AppFailure map(String code) =>
        mapAuthError(AuthApiException('x', statusCode: '400', code: code));

    expect(map('invalid_credentials'), isA<InvalidCredentialsFailure>());
    expect(map('user_already_exists'), isA<EmailAlreadyRegisteredFailure>());
    expect(map('email_exists'), isA<EmailAlreadyRegisteredFailure>());
    expect(map('weak_password'), isA<WeakPasswordFailure>());
    expect(map('otp_expired'), isA<InvalidCodeFailure>());
    expect(map('over_email_send_rate_limit'), isA<RateLimitedFailure>());
    expect(map('something_new'), isA<UnexpectedFailure>());
  });

  test('the signup trigger rejection becomes ConsentRequiredFailure', () {
    // Lo que recibe el cliente de Dart cuando private.handle_new_user rechaza
    // el registro (comprobado contra el Supabase local).
    final error = AuthRetryableFetchException(
      message:
          '{"code":"unexpected_failure","message":"Database error saving new user"}',
      statusCode: '500',
    );

    expect(mapAuthError(error), isA<ConsentRequiredFailure>());
  });

  test('only errors without an HTTP response are network failures', () {
    expect(
      mapAuthError(AuthRetryableFetchException(message: 'sin red')),
      isA<NetworkFailure>(),
    );
    expect(
      mapAuthError(AuthRetryableFetchException(message: 'caído', statusCode: '503')),
      isA<UnexpectedFailure>(),
    );
    expect(mapAuthError(TimeoutException('lento')), isA<NetworkFailure>());
  });

  test('PostgREST errors use the contract mapping', () {
    expect(
      mapAuthError(const PostgrestException(message: 'x', code: 'VALIDATION_ERROR')),
      isA<ValidationFailure>(),
    );
  });
}
