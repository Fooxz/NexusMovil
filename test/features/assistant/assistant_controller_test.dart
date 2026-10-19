import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/core/errors/app_failure.dart';
import 'package:prueba01/features/assistant/assistant_providers.dart';
import 'package:prueba01/features/assistant/domain/assistant_models.dart';

import '../../support/assistant_test_support.dart';

void main() {
  late ScriptedAssistant assistant;
  late ProviderContainer container;

  ProviderContainer start(List<Object> script) {
    assistant = ScriptedAssistant(script);
    container = ProviderContainer(
      overrides: [assistantRepositoryProvider.overrideWithValue(assistant)],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    return container;
  }

  AssistantController controller() => container.read(assistantControllerProvider.notifier);
  AssistantState state() => container.read(assistantControllerProvider);

  test('a question and its answer stay in the conversation', () async {
    start([const AssistantQuestion('¿Cuál es tu presupuesto?')]);

    final sending = controller().send('  Necesito un PC de oficina  ');
    expect(state().sending, isTrue);
    expect((state().entries.single as UserEntry).text, 'Necesito un PC de oficina');
    await sending;

    expect(state().sending, isFalse);
    expect((state().entries.last as ReplyEntry).reply.message, '¿Cuál es tu presupuesto?');
  });

  test('sends the whole conversation, with what it recommended before', () async {
    start([
      const AssistantQuestion('¿Presupuesto?'),
      const AssistantRecommendation('Te sirve este.'),
    ]);
    await controller().send('Un PC para editar video');
    await controller().send('8 millones');

    expect(
      assistant.conversations.last.map((turn) => '${turn.role.name}: ${turn.text}'),
      ['user: Un PC para editar video', 'assistant: ¿Presupuesto?', 'user: 8 millones'],
    );
    expect(assistant.sessionIds.toSet(), hasLength(1), reason: 'misma sesión');
  });

  test('ignores empty messages and a second message while waiting', () async {
    start([const AssistantQuestion('¿Presupuesto?')]);
    assistant.gate = Completer<void>();

    await controller().send('   ');
    expect(state().isEmpty, isTrue);

    final first = controller().send('Un PC');
    await controller().send('Otro mensaje');
    assistant.gate!.complete();
    await first;

    expect(assistant.conversations, hasLength(1));
    expect(state().entries, hasLength(2));
  });

  test('an error can be retried without repeating the message', () async {
    start([const AssistantUnavailableFailure(), const AssistantQuestion('¿Presupuesto?')]);
    await controller().send('Un PC');

    expect((state().entries.last as FailureEntry).failure, isA<AssistantUnavailableFailure>());
    expect(state().canRetry, isTrue);

    await controller().retry();
    expect(state().entries.map((entry) => entry.runtimeType), [UserEntry, ReplyEntry]);
    expect(assistant.conversations.last.single.text, 'Un PC');
  });

  test('a new message after an error drops the error', () async {
    start([const NetworkFailure(), const AssistantQuestion('¿Presupuesto?')]);
    await controller().send('Un PC');
    await controller().send('Un PC para jugar');

    expect(state().entries.whereType<FailureEntry>(), isEmpty);
    expect(assistant.conversations.last.map((turn) => turn.text), ['Un PC', 'Un PC para jugar']);
  });

  test('starting over discards an answer still on its way', () async {
    start([const AssistantQuestion('¿Presupuesto?'), const AssistantQuestion('¿Uso?')]);
    assistant.gate = Completer<void>();
    final pending = controller().send('Un PC');

    controller().restart();
    assistant.gate!.complete();
    await pending;
    expect(state().isEmpty, isTrue);

    assistant.gate = null;
    await controller().send('Otro PC');
    expect(assistant.sessionIds.toSet(), hasLength(2), reason: 'sesión nueva');
  });

  test('only the last turns are sent', () async {
    start([for (var i = 0; i < 8; i++) AssistantQuestion('Pregunta $i')]);
    for (var i = 0; i < 8; i++) {
      await controller().send('Mensaje $i');
    }

    final sent = assistant.conversations.last;
    expect(sent, hasLength(AssistantController.historyLimit));
    expect(sent.last.text, 'Mensaje 7');
    expect(sent.first.role, ChatRole.assistant);
  });
}
