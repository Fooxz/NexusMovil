import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_failure.dart';
import '../../core/network/supabase_providers.dart';
import '../catalog/catalog_providers.dart';
import '../catalog/data/mock_product_repository.dart';
import 'data/mock_assistant_repository.dart';
import 'data/supabase_assistant_repository.dart';
import 'domain/assistant_models.dart';
import 'domain/assistant_repository.dart';

/// Con el mock del catálogo usa el mock del asistente (que dice que no
/// funciona sin backend); si no, la Edge Function `assistant`.
final assistantRepositoryProvider = Provider<AssistantRepository>((ref) {
  if (ref.watch(productRepositoryProvider) is MockProductRepository) {
    return MockAssistantRepository();
  }
  return SupabaseAssistantRepository.fromClient(
    ref.watch(supabaseClientProvider),
  );
});


/// Una entrada del chat: lo que escribió el cliente, la respuesta del
/// asistente o un error que se puede reintentar.
sealed class ChatEntry {
  const ChatEntry();
}

class UserEntry extends ChatEntry {
  const UserEntry(this.text);

  final String text;
}

class ReplyEntry extends ChatEntry {
  const ReplyEntry(this.reply);

  final AssistantReply reply;
}

class FailureEntry extends ChatEntry {
  const FailureEntry(this.failure);

  final AppFailure failure;
}

class AssistantState {
  AssistantState({List<ChatEntry> entries = const [], this.sending = false})
    : entries = List.unmodifiable(entries);

  final List<ChatEntry> entries;

  /// Esperando la respuesta: se bloquea el envío para no cruzar turnos.
  final bool sending;

  bool get isEmpty => entries.isEmpty;

  bool get canRetry => !sending && entries.isNotEmpty && entries.last is FailureEntry;
}

/// La conversación vive fuera del árbol de widgets y se conserva al cambiar
/// de pestaña mientras la app está abierta.
final assistantControllerProvider =
    NotifierProvider<AssistantController, AssistantState>(AssistantController.new);

class AssistantController extends Notifier<AssistantState> {
  /// Turnos que se reenvían: los mismos que acepta la función.
  static const historyLimit = 12;

  late String _sessionId;

  @override
  AssistantState build() {
    _sessionId = _newSessionId();
    return AssistantState();
  }

  /// Envía [text] y espera la respuesta. No hace nada si está vacío o si ya
  /// hay una pregunta en curso.
  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.sending) return;
    state = AssistantState(
      entries: [
        for (final entry in state.entries)
          if (entry is! FailureEntry) entry,
        UserEntry(trimmed),
      ],
      sending: true,
    );
    await _ask();
  }

  /// Vuelve a enviar la última pregunta después de un error.
  Future<void> retry() async {
    if (!state.canRetry) return;
    state = AssistantState(
      entries: state.entries.sublist(0, state.entries.length - 1),
      sending: true,
    );
    await _ask();
  }

  /// Empieza una conversación nueva.
  void restart() {
    _sessionId = _newSessionId();
    state = AssistantState();
  }

  Future<void> _ask() async {
    final sessionId = _sessionId;
    final conversation = [
      for (final entry in state.entries)
        switch (entry) {
          UserEntry(:final text) => ChatTurn(ChatRole.user, text),
          ReplyEntry(:final reply) => ChatTurn(ChatRole.assistant, reply.historyText),
          FailureEntry() => null,
        },
    ].nonNulls.toList();
    final recent = conversation.length > historyLimit
        ? conversation.sublist(conversation.length - historyLimit)
        : conversation;

    ChatEntry answer;
    try {
      answer = ReplyEntry(
        await ref.read(assistantRepositoryProvider).ask(recent, sessionId: sessionId),
      );
    } on AppFailure catch (failure) {
      answer = FailureEntry(failure);
    }
    // Si se empezó otra conversación mientras esperaba, la respuesta se descarta.
    if (!ref.mounted || sessionId != _sessionId) return;
    state = AssistantState(entries: [...state.entries, answer]);
  }

  static String _newSessionId() {
    final random = Random.secure();
    return List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }
}
