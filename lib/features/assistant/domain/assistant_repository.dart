import 'assistant_models.dart';

/// Asistente de recomendación (HU-006). Errores como `AppFailure`; si la IA
/// no está disponible, `AssistantUnavailableFailure` (RNF-018).
abstract class AssistantRepository {
  /// Envía la conversación (el último turno es del cliente) y devuelve la
  /// respuesta. [sessionId] agrupa los turnos para la trazabilidad (RF-043).
  Future<AssistantReply> ask(List<ChatTurn> conversation, {required String sessionId});
}
