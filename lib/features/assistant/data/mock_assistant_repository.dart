import '../domain/assistant_models.dart';
import '../domain/assistant_repository.dart';

/// Asistente sin backend. No hay modelo de IA ni catálogo con atributos, así
/// que no recomienda: lo dice y ofrece las otras formas de comprar, en vez de
/// inventar una respuesta.
class MockAssistantRepository implements AssistantRepository {
  MockAssistantRepository({this.latency = const Duration(milliseconds: 400)});

  final Duration latency;

  static const offlineMessage =
      'Modo sin backend: el asistente necesita conectarse al servidor para '
      'recomendarte productos. Mientras tanto, puedes buscar en el catálogo o '
      'armar tu equipo en el PC Builder.';

  @override
  Future<AssistantReply> ask(
    List<ChatTurn> conversation, {
    required String sessionId,
  }) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return const AssistantNoMatch(offlineMessage);
  }
}
