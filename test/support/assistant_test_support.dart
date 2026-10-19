import 'dart:async';

import 'package:prueba01/core/errors/app_failure.dart';
import 'package:prueba01/features/assistant/data/voice_input.dart';
import 'package:prueba01/features/assistant/domain/assistant_models.dart';
import 'package:prueba01/features/assistant/domain/assistant_repository.dart';

/// Asistente guionado: devuelve las respuestas (o lanza los errores) en orden
/// y guarda cada conversación recibida.
class ScriptedAssistant implements AssistantRepository {
  ScriptedAssistant(List<Object> script) : _script = [...script];

  final List<Object> _script;
  final conversations = <List<ChatTurn>>[];
  final sessionIds = <String>[];

  /// Si no es nulo, la próxima respuesta espera a que se complete.
  Completer<void>? gate;

  @override
  Future<AssistantReply> ask(
    List<ChatTurn> conversation, {
    required String sessionId,
  }) async {
    conversations.add(conversation);
    sessionIds.add(sessionId);
    if (gate case final gate?) await gate.future;
    final next = _script.removeAt(0);
    if (next is AppFailure) throw next;
    return next as AssistantReply;
  }
}

/// Dictado falso: decide si hay micrófono y permite simular lo que se oye.
class FakeVoiceInput implements VoiceInput {
  FakeVoiceInput({this.available = true});

  final bool available;
  bool listening = false;
  void Function(String text)? _onText;
  void Function()? _onDone;

  @override
  Future<bool> initialize() async => available;

  @override
  Future<void> listen({
    required void Function(String text) onText,
    required void Function() onDone,
  }) async {
    listening = true;
    _onText = onText;
    _onDone = onDone;
  }

  void hear(String text) => _onText!(text);

  void finish() {
    listening = false;
    _onDone!();
  }

  @override
  Future<void> stop() async => listening = false;
}
