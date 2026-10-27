import '../../catalog/domain/product.dart';
import '../../pc_builder/domain/pc_builder_models.dart';

/// Turno de la conversación que se envía al asistente.
enum ChatRole { user, assistant }

class ChatTurn {
  const ChatTurn(this.role, this.text);

  final ChatRole role;
  final String text;
}

/// Respuesta del asistente (API_CONTRATO, parte 4). Siempre es texto
/// generado con IA a partir del catálogo (RNF-025); nunca compra nada.
sealed class AssistantReply {
  const AssistantReply(this.message);

  final String message;

  /// Cómo se resume esta respuesta en el historial que se reenvía, para que
  /// el asistente sepa qué recomendó antes.
  String get historyText => message;
}

/// Falta información (uso o presupuesto) para recomendar (RF-037).
class AssistantQuestion extends AssistantReply {
  const AssistantQuestion(super.message);
}

/// No hay nada adecuado o la petición no es sobre computadores (RF-041).
class AssistantNoMatch extends AssistantReply {
  const AssistantNoMatch(super.message);
}

/// Piezas sueltas (si el cliente busca una pieza o mejorar su equipo) y/o
/// una configuración completa validada por el motor de compatibilidad
/// (RF-038 a RF-040).
class AssistantRecommendation extends AssistantReply {
  const AssistantRecommendation(
    super.message, {
    this.products = const [],
    this.build,
  });

  final List<RecommendedProduct> products;
  final ProposedBuild? build;

  @override
  String get historyText => [
    message,
    for (final item in products) 'Recomendé ${item.product.name} (${item.product.id}).',
    if (build case final build?)
      'Propuse una configuración de piezas: '
          '${build.validation.parts.map((part) => '${part.productName} (${part.offerId})').join(', ')}.',
  ].join('\n');
}

class RecommendedProduct {
  const RecommendedProduct({required this.product, required this.reason});

  final Product product;

  /// Por qué le sirve, según sus atributos reales.
  final String reason;
}

/// Configuración de piezas propuesta. El servidor ya la validó: es
/// compatible y se puede comprar.
class ProposedBuild {
  const ProposedBuild({required this.reason, required this.validation});

  final String reason;
  final BuildValidation validation;

  List<String> get offerIds => [
    for (final part in validation.parts) part.offerId,
  ];
}
