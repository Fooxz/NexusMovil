import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/core/errors/app_failure.dart';
import 'package:prueba01/features/assistant/data/assistant_json.dart';
import 'package:prueba01/features/assistant/data/mock_assistant_repository.dart';
import 'package:prueba01/features/assistant/data/supabase_assistant_repository.dart';
import 'package:prueba01/features/assistant/domain/assistant_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../pc_builder/pc_builder_data_test.dart' show validationJson;
import '../../support/contract_fixtures.dart';

/// Respuesta de la función `assistant` (API_CONTRATO, parte 4).
final recommendationJson = {
  'type': 'recommendation',
  'message': 'Este equipo te sirve para editar video.',
  'products': [
    {'product': contractDetailFixture, 'reason': '16 GB de video para renderizar.'},
    {'product': {'id': 'roto'}, 'reason': 'Se omite: no es un producto válido.'},
  ],
  'build': {'reason': 'Equilibrado para 4K.', 'validation': validationJson},
  'interactionId': 'f7b369de-20e2-4a23-ab7a-896e450fb762',
  'sessionId': 'sesion-123',
};

void main() {
  test('reads a recommendation with products and a parts build', () {
    final reply = assistantReplyFromJson(recommendationJson) as AssistantRecommendation;

    expect(reply.message, 'Este equipo te sirve para editar video.');
    expect(reply.products.single.product.id, contractDetailFixture['id']);
    expect(reply.products.single.reason, '16 GB de video para renderizar.');
    expect(reply.build!.reason, 'Equilibrado para 4K.');
    expect(reply.build!.offerIds, ['off-tp-9950x', 'off-mp-z790hero']);
  });

  test('reads questions and no matches, and rejects unknown types', () {
    expect(
      assistantReplyFromJson({'type': 'question', 'message': '¿Presupuesto?'}),
      isA<AssistantQuestion>(),
    );
    expect(
      assistantReplyFromJson({'type': 'noMatch', 'message': 'Solo computadores.'}),
      isA<AssistantNoMatch>(),
    );
    expect(() => assistantReplyFromJson({'type': 'otro', 'message': 'x'}), throwsFormatException);
    expect(() => assistantReplyFromJson({'message': 'x'}), throwsFormatException);
  });

  test('the history keeps what was recommended, for follow-up questions', () {
    final reply = assistantReplyFromJson(recommendationJson) as AssistantRecommendation;

    expect(reply.historyText, contains('Recomendé ${reply.products.single.product.name}'));
    expect(reply.historyText, contains('(off-tp-9950x)'));
  });

  test('sends the conversation and the session', () {
    expect(
      assistantRequestJson(const [
        ChatTurn(ChatRole.user, 'Un PC'),
        ChatTurn(ChatRole.assistant, '¿Presupuesto?'),
        ChatTurn(ChatRole.user, '3 millones'),
      ], 'sesion-123'),
      {
        'sessionId': 'sesion-123',
        'messages': [
          {'role': 'user', 'text': 'Un PC'},
          {'role': 'assistant', 'text': '¿Presupuesto?'},
          {'role': 'user', 'text': '3 millones'},
        ],
      },
    );
  });

  group('Supabase repository', () {
    Future<AssistantReply> askWith(Future<Object?> Function() response) =>
        SupabaseAssistantRepository((name, body) {
          expect(name, 'assistant');
          return response();
        }).ask(const [ChatTurn(ChatRole.user, 'Un PC')], sessionId: 'sesion-123');

    test('returns the reply of the function', () async {
      final reply = await askWith(() async => {'type': 'question', 'message': '¿Presupuesto?'});
      expect(reply.message, '¿Presupuesto?');
    });

    test('an AI outage is explained without breaking the app (RNF-018)', () async {
      await expectLater(
        askWith(() => throw const FunctionsHttpException(
          status: 503,
          details: {'code': 'ASSISTANT_UNAVAILABLE', 'message': 'x'},
        )),
        throwsA(isA<AssistantUnavailableFailure>()),
      );
    });

    test('too many questions and network errors have their own message', () async {
      await expectLater(
        askWith(() => throw const FunctionsHttpException(
          status: 429,
          details: {'code': 'RATE_LIMITED'},
        )),
        throwsA(isA<RateLimitedFailure>()),
      );
      await expectLater(
        askWith(() => throw const FunctionsFetchException(details: 'sin red')),
        throwsA(isA<NetworkFailure>()),
      );
      await expectLater(
        askWith(() async => {'nope': true}),
        throwsA(isA<UnexpectedFailure>()),
      );
    });
  });

  test('without backend it says so instead of recommending', () async {
    final reply = await MockAssistantRepository(latency: Duration.zero)
        .ask(const [ChatTurn(ChatRole.user, 'Un PC')], sessionId: 'sesion-123');

    expect(reply, isA<AssistantNoMatch>());
    expect(reply.message, MockAssistantRepository.offlineMessage);
  });
}
