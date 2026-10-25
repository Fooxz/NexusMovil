import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../assistant/data/supabase_assistant_repository.dart' show FunctionCall;
import '../domain/checkout_models.dart';
import '../domain/checkout_repository.dart';
import 'checkout_json.dart';

/// Checkout con la Edge Function `checkout` (API_CONTRATO, parte 5). El
/// cliente de Supabase envía el token de la sesión; sin sesión responde 401.
class SupabaseCheckoutRepository implements CheckoutRepository {
  SupabaseCheckoutRepository(this._call);

  factory SupabaseCheckoutRepository.fromClient(SupabaseClient client) =>
      SupabaseCheckoutRepository(
        (name, body) async => (await client.functions.invoke(name, body: body)).data,
      );

  final FunctionCall _call;

  @override
  Future<CheckoutSession> start({
    required String addressId,
    required CheckoutContact contact,
    required int expectedTotalCents,
  }) => _invoke({
    'action': 'start',
    'addressId': addressId,
    'contact': contact.toJson(),
    'expectedTotalCents': expectedTotalCents,
  }, checkoutSessionFromJson);

  @override
  Future<CheckoutStatus> status(String reference, {String? transactionId}) =>
      _invoke({
        'action': 'status',
        'reference': reference,
        'transactionId': ?transactionId,
      }, checkoutStatusFromJson);

  Future<T> _invoke<T>(
    Map<String, Object?> body,
    T Function(Object? json) parse,
  ) async {
    final Object? json;
    try {
      json = await _call('checkout', body);
    } on FunctionsFetchException {
      throw const NetworkFailure();
    } on FunctionException catch (error) {
      final details = error.details;
      throw AppFailure.fromApiError(
        statusCode: error.status,
        code: details is Map ? details['code'] as String? : null,
        details: details is Map ? details['details'] : null,
      );
    } on AppFailure {
      rethrow;
    } on Exception {
      throw const NetworkFailure();
    }
    try {
      return parse(json);
    } on FormatException {
      throw const UnexpectedFailure();
    }
  }
}
