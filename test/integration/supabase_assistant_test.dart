// Prueba de integración del asistente contra la Edge Function local. Se salta
// sin configuración; ver supabase_catalog_test.dart para ejecutarla. La
// función debe estar servida:
//   npx supabase functions serve --env-file supabase/functions/.env
//
// La prueba con el modelo real gasta cuota de Gemini, así que solo corre con
//   --dart-define=ASSISTANT_LIVE=true
@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/core/config/env.dart';
import 'package:prueba01/core/errors/app_failure.dart';
import 'package:prueba01/features/assistant/data/supabase_assistant_repository.dart';
import 'package:prueba01/features/assistant/domain/assistant_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/integration_support.dart';

void main() {
  const env = AppEnv.fromEnvironment();
  const live = bool.fromEnvironment('ASSISTANT_LIVE');
  final skip = integrationSkip(env);

  late SupabaseAssistantRepository assistant;

  setUpAll(() {
    if (skip != false) return;
    assistant = SupabaseAssistantRepository.fromClient(
      SupabaseClient(env.supabaseUrl, env.supabasePublishableKey),
    );
  });

  test('the function validates the conversation before calling the model', () async {
    await expectLater(
      assistant.ask(const [
        ChatTurn(ChatRole.user, 'Hola'),
        ChatTurn(ChatRole.assistant, 'El último turno debe ser del cliente'),
      ], sessionId: 'integracion-001'),
      throwsA(isA<ValidationFailure>()),
    );
  }, skip: skip);

  test('asks for the budget when it is missing (RF-037, uses Gemini)', () async {
    final reply = await assistant.ask(const [
      ChatTurn(ChatRole.user, 'Necesito un computador de oficina para trabajar y editar videos'),
    ], sessionId: 'integracion-002');

    expect(reply, isA<AssistantQuestion>());
    expect(reply.message.toLowerCase(), contains('presupuesto'));
  }, skip: skip != false ? skip : (live ? false : 'Gasta cuota de Gemini: usa ASSISTANT_LIVE=true'),
     timeout: const Timeout(Duration(minutes: 2)));
}
