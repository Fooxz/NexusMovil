import '../../catalog/domain/product.dart';
import '../domain/build_scene.dart';

/// Lectura de `get_build_scene` (API_CONTRATO, parte 3). [modelUrl] convierte
/// la ruta del archivo en el bucket en una dirección descargable. Las piezas
/// de categorías desconocidas se omiten; un modelo mal formado se ignora (la
/// app genera la pieza) en vez de romper la vista.
BuildScene buildSceneFromJson(
  Object? json, {
  required String Function(String path) modelUrl,
}) {
  if (json case {'parts': List<Object?> parts}) {
    return BuildScene(
      parts: [for (final part in parts) ?_partFromJson(part, modelUrl)],
    );
  }
  throw FormatException('Escena inválida', json);
}

ScenePart? _partFromJson(Object? json, String Function(String) modelUrl) {
  if (json case {
    'offerId': String offerId,
    'category': String categoryName,
    'productName': String productName,
  }) {
    final category = ProductCategory.values.asNameMap()[categoryName];
    if (category == null) return null;
    final attributes = json['attributes'];
    return ScenePart(
      offerId: offerId,
      category: category,
      productName: productName,
      model: _modelFromJson(json['model'], modelUrl),
      attributes: attributes is Map<String, Object?>
          ? Map.unmodifiable(attributes)
          : const {},
    );
  }
  throw FormatException('Pieza de la escena inválida', json);
}

PartModel? _modelFromJson(Object? json, String Function(String) modelUrl) {
  if (json case {
    'path': String path,
    'rotation': [num x, num y, num z],
    'title': String title,
    'author': String author,
    'license': String license,
  }) {
    final source = json['sourceUrl'];
    return PartModel(
      url: modelUrl(path),
      rotation: [x.toDouble(), y.toDouble(), z.toDouble()],
      generic: json['generic'] == true,
      credit: ModelCredit(
        title: title,
        author: author,
        license: license,
        sourceUrl: source is String ? source : null,
      ),
    );
  }
  return null;
}
