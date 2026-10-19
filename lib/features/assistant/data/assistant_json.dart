import '../../catalog/data/product_json.dart';
import '../../catalog/domain/product.dart';
import '../../pc_builder/data/pc_builder_json.dart';
import '../domain/assistant_models.dart';

/// Lectura de la respuesta de la función `assistant` (API_CONTRATO, parte 4).
/// Lanza `FormatException` si falta un campo obligatorio. Un producto que no
/// se puede leer se omite.
AssistantReply assistantReplyFromJson(Object? json) {
  if (json case {'type': String type, 'message': String message}) {
    return switch (type) {
      'question' => AssistantQuestion(message),
      'noMatch' => AssistantNoMatch(message),
      'recommendation' => AssistantRecommendation(
        message,
        products: [
          for (final item in json['products'] as List<Object?>? ?? const [])
            if (item case {'product': final Object product, 'reason': final String reason})
              if (_productOrNull(product) case final product?)
                RecommendedProduct(product: product, reason: reason),
        ],
        build: switch (json['build']) {
          {'reason': final String reason, 'validation': final Object validation} =>
            ProposedBuild(
              reason: reason,
              validation: buildValidationFromJson(validation),
            ),
          _ => null,
        },
      ),
      _ => throw FormatException('Tipo de respuesta desconocido', type),
    };
  }
  throw FormatException('Respuesta del asistente inválida', json);
}

Product? _productOrNull(Object json) {
  try {
    return productFromJson(json);
  } on FormatException {
    return null;
  }
}

/// Cuerpo que se envía a la función.
Map<String, Object?> assistantRequestJson(
  List<ChatTurn> conversation,
  String sessionId,
) => {
  'sessionId': sessionId,
  'messages': [
    for (final turn in conversation) {'role': turn.role.name, 'text': turn.text},
  ],
};
