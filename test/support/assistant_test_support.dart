import 'dart:async';

import 'package:prueba01/core/errors/app_failure.dart';
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
