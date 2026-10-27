import '../../catalog/domain/product.dart';

/// Datos para la vista 3D de una configuración (RF-090): por cada pieza, su
/// modelo 3D (si hay) y los atributos que cambian cómo se ve.
class BuildScene {
  const BuildScene({required this.parts});

  static const empty = BuildScene(parts: []);

  final List<ScenePart> parts;

  ScenePart? partFor(ProductCategory category) {
    for (final part in parts) {
      if (part.category == category) return part;
    }
    return null;
  }
}

class ScenePart {
  const ScenePart({
    required this.offerId,
    required this.category,
    required this.productName,
    this.model,
    this.attributes = const {},
  });

  final String offerId;
  final ProductCategory category;
  final String productName;

  /// Sin modelo, el visor genera la pieza con su forma y medidas típicas.
  final PartModel? model;

  /// Atributos visuales, por ejemplo `form_factor`, `modules` o `length_mm`.
  final Map<String, Object?> attributes;

  num? number(String key) => switch (attributes[key]) {
    final num value => value,
    _ => null,
  };

  String? text(String key) => switch (attributes[key]) {
    final String value => value,
    _ => null,
  };
}

/// Archivo `.glb` de una pieza y quién lo hizo.
class PartModel {
  const PartModel({
    required this.url,
    required this.credit,
    this.rotation = const [0, 0, 0],
    this.generic = false,
  });

  final String url;

  /// Grados (X, Y, Z) que dejan el modelo en la orientación de su categoría:
  /// largo en X, alto en Y y la cara principal mirando a +Z.
  final List<double> rotation;

  /// Modelo genérico de la categoría, no del producto exacto.
  final bool generic;

  final ModelCredit credit;
}

/// Crédito que exige la licencia del modelo (por ejemplo, CC BY).
class ModelCredit {
  const ModelCredit({
    required this.title,
    required this.author,
    required this.license,
    this.sourceUrl,
  });

  final String title;
  final String author;
  final String license;
  final String? sourceUrl;

  bool get requiresAttribution => license != 'CC0-1.0';

  @override
  bool operator ==(Object other) =>
      other is ModelCredit &&
      other.title == title &&
      other.author == author &&
      other.license == license &&
      other.sourceUrl == sourceUrl;

  @override
  int get hashCode => Object.hash(title, author, license, sourceUrl);
}
