import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/nexus_theme.dart';
import '../assistant_providers.dart';

/// Campo para escribir o dictar (RF-089). El dictado llena el campo y el
/// cliente revisa el texto antes de enviarlo: nada se envía solo.
class VoiceComposer extends ConsumerStatefulWidget {
  const VoiceComposer({super.key});

  /// El mismo límite que acepta la función del asistente.
  static const maxLength = 1000;

  @override
  ConsumerState<VoiceComposer> createState() => _VoiceComposerState();
}

class _VoiceComposerState extends ConsumerState<VoiceComposer> {
  final _text = TextEditingController();
  bool _listening = false;

  @override
  void dispose() {
    if (_listening) ref.read(voiceInputProvider).stop();
    _text.dispose();
    super.dispose();
  }

  Future<void> _toggleVoice() async {
    final voice = ref.read(voiceInputProvider);
    if (_listening) {
      await voice.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (!await voice.initialize()) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text(
            'El dictado por voz no está disponible en este dispositivo o falta '
            'el permiso del micrófono.',
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _listening = true);
    await voice.listen(
      onText: (text) {
        if (!mounted) return;
        _text.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      },
      onDone: () {
        if (mounted) setState(() => _listening = false);
      },
    );
  }

  void _send() {
    final text = _text.text.trim();
    if (text.isEmpty || ref.read(assistantControllerProvider).sending) return;
    if (_listening) {
      ref.read(voiceInputProvider).stop();
      setState(() => _listening = false);
    }
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
              maxLength: VoiceComposer.maxLength,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              style: const TextStyle(color: NexusColors.text, fontSize: 14),
              decoration: InputDecoration(
                hintText: _listening ? 'Escuchando...' : 'Describe el computador que necesitas',
                hintStyle: TextStyle(
                  color: _listening ? NexusColors.pink : NexusColors.textFaint,
                ),
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
            tooltip: _listening ? 'Dejar de escuchar' : 'Dictar por voz',
            onPressed: _toggleVoice,
            icon: Icon(
              _listening ? Icons.mic : Icons.mic_none,
              color: _listening ? NexusColors.pink : NexusColors.textDim,
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
