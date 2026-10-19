import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../domain/assistant_models.dart';
import '../domain/assistant_repository.dart';
import 'assistant_json.dart';

/// Llama a una Edge Function y devuelve el JSON de su respuesta. Lanza
/// `FunctionException` si responde con error.
typedef FunctionCall =
    Future<Object?> Function(String name, Map<String, Object?> body);

/// Asistente con la Edge Function `assistant` (API_CONTRATO, parte 4). Si hay
/// sesión, el cliente de Supabase envía su token y la interacción queda
/// asociada a la cuenta.
class SupabaseAssistantRepository implements AssistantRepository {
  SupabaseAssistantRepository(this._call);

  factory SupabaseAssistantRepository.fromClient(SupabaseClient client) =>
      SupabaseAssistantRepository(
        (name, body) async => (await client.functions.invoke(name, body: body)).data,
      );

  final FunctionCall _call;

  @override
  Future<AssistantReply> ask(
    List<ChatTurn> conversation, {
    required String sessionId,
  }) async {
    final Object? json;
    try {
      json = await _call('assistant', assistantRequestJson(conversation, sessionId));
    } on FunctionsFetchException {
      throw const NetworkFailure();
    } on FunctionException catch (error) {
      final details = error.details;
      throw AppFailure.fromApiError(
        statusCode: error.status,
        code: details is Map ? details['code'] as String? : null,
      );
    } on AppFailure {
      rethrow;
    } on Exception {
      throw const NetworkFailure();
    }
    try {
      return assistantReplyFromJson(json);
    } on FormatException {
      throw const UnexpectedFailure();
    }
  }
}
