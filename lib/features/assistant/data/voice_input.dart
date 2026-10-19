import 'package:speech_to_text/speech_to_text.dart';

/// Dictado por voz (RF-089). El reconocedor es el del dispositivo (Android,
/// iOS o el navegador): NEXUS no recibe ni guarda el audio, solo el texto que
/// el cliente revisa y envía.
abstract class VoiceInput {
  /// Prepara el reconocedor y pide permiso del micrófono la primera vez.
  /// `false` si el dispositivo no tiene dictado o el permiso se negó.
  Future<bool> initialize();

  /// Escucha hasta una pausa. [onText] recibe el texto reconocido hasta el
  /// momento; [onDone] avisa que dejó de escuchar.
  Future<void> listen({
    required void Function(String text) onText,
    required void Function() onDone,
  });

  Future<void> stop();
}

class DeviceVoiceInput implements VoiceInput {
  final _speech = SpeechToText();
  bool? _available;
  String? _localeId;
  void Function()? _onDone;

  @override
  Future<bool> initialize() async {
    if (_available case final available?) return available;
    try {
      _available = await _speech.initialize(
        onStatus: (status) {
          if (status == SpeechToText.doneStatus ||
              status == SpeechToText.notListeningStatus) {
            _onDone?.call();
          }
        },
        onError: (_) => _onDone?.call(),
      );
    } on Exception {
      _available = false;
    }
    if (_available!) _localeId = await _spanishLocale();
    return _available!;
  }

  /// Español de Colombia si está, si no cualquier español, si no el del
  /// sistema.
  Future<String?> _spanishLocale() async {
    final locales = await _speech.locales();
    String normalize(String id) => id.replaceAll('-', '_').toLowerCase();
    for (final wanted in ['es_co', 'es_419', 'es_us', 'es_mx', 'es_es']) {
      for (final locale in locales) {
        if (normalize(locale.localeId) == wanted) return locale.localeId;
      }
    }
    for (final locale in locales) {
      if (normalize(locale.localeId).startsWith('es')) return locale.localeId;
    }
    return null;
  }

  @override
  Future<void> listen({
    required void Function(String text) onText,
    required void Function() onDone,
  }) async {
    _onDone = onDone;
    await _speech.listen(
      onResult: (result) => onText(result.recognizedWords),
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 4),
        autoPunctuation: true,
        localeId: _localeId,
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  @override
  Future<void> stop() => _speech.stop();
}
