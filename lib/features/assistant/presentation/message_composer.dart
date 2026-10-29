import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/nexus_theme.dart';
import '../assistant_providers.dart';

/// Campo para escribir la necesidad al asistente.
class MessageComposer extends ConsumerStatefulWidget {
  const MessageComposer({super.key});

  /// El mismo límite que acepta la función del asistente.
  static const maxLength = 1000;

  @override
  ConsumerState<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends ConsumerState<MessageComposer> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _send() {
    final text = _text.text.trim();
    if (text.isEmpty || ref.read(assistantControllerProvider).sending) return;
    _text.clear();
    ref.read(assistantControllerProvider.notifier).send(text);
  }

  @override
  Widget build(BuildContext context) {
    final sending = ref.watch(assistantControllerProvider.select((state) => state.sending));
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: const BoxDecoration(
        color: NexusColors.bgAlt,
        border: Border(top: BorderSide(color: NexusColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _text,
              minLines: 1,
              maxLines: 4,
              maxLength: MessageComposer.maxLength,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              style: const TextStyle(color: NexusColors.text, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Describe el computador que necesitas',
                hintStyle: const TextStyle(color: NexusColors.textFaint),
                counterText: '',
                isDense: true,
                filled: true,
                fillColor: NexusColors.card,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: NexusColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: NexusColors.border),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Enviar',
            onPressed: sending ? null : _send,
            icon: const Icon(Icons.send),
            color: NexusColors.cyan,
            disabledColor: NexusColors.textFaint,
          ),
        ],
      ),
    );
  }
}
