import '../../catalog/domain/product.dart';

/// Ranura del armador: un tipo de pieza (RF-046).
class BuilderSlot {
  const BuilderSlot({
    required this.category,
    required this.label,
    required this.required,
  });

  final ProductCategory category;
  final String label;

  /// Obligatoria para que la configuración sea válida (RF-048). La gráfica no
  /// lo es: la exige una regla si el procesador no tiene gráficos integrados.
  final bool required;
}

/// Pieza elegida, con sus datos vigentes.
class BuildPart {
  const BuildPart({
    required this.offerId,
    required this.category,
    required this.productId,
    required this.productName,
    required this.brand,
    required this.providerName,
    required this.priceCents,
    required this.isAvailable,
    this.imageUrl,
  });

  final String offerId;
  final ProductCategory category;
  final String productId;
  final String productName;
  final String brand;
  final String providerName;
  final int priceCents;
  final bool isAvailable;
  final String? imageUrl;
}

enum IssueSeverity { error, warning }

/// Resultado de una regla de compatibilidad (RF-047). [offerIds] son las
/// piezas que la causan. Un `warning` avisa que no se pudo verificar algo.
class BuildIssue {
  const BuildIssue({
    required this.ruleCode,
    required this.severity,
    required this.message,
    required this.offerIds,
  });

  final String ruleCode;
  final IssueSeverity severity;
  final String message;
  final List<String> offerIds;

  bool get isError => severity == IssueSeverity.error;
}

/// Evaluación de una configuración por el motor de reglas del backend.
class BuildValidation {
  const BuildValidation({
    required this.valid,
    required this.purchasable,
    required this.parts,
    required this.issues,
    required this.missingSlots,
    required this.totalCents,
  });

  const BuildValidation.empty()
    : valid = false,
      purchasable = false,
      parts = const [],
      issues = const [],
      missingSlots = const [],
      totalCents = 0;

  /// Sin incompatibilidades ni piezas obligatorias faltantes (RN-031).
  final bool valid;

  /// Válida y con todas las piezas disponibles: se puede agregar al carrito.
  final bool purchasable;
  final List<BuildPart> parts;
  final List<BuildIssue> issues;

  /// Ranuras obligatorias sin pieza, en orden.
  final List<BuilderSlot> missingSlots;
  final int totalCents;

  Iterable<BuildIssue> get errors => issues.where((issue) => issue.isError);
  Iterable<BuildIssue> get warnings => issues.where((issue) => !issue.isError);

  BuildPart? partFor(ProductCategory category) {
    for (final part in parts) {
      if (part.category == category) return part;
    }
    return null;
  }

  List<BuildIssue> issuesFor(String offerId) => [
    for (final issue in issues)
      if (issue.offerIds.contains(offerId)) issue,
  ];
}

/// Pieza que se puede elegir para una ranura, con su compatibilidad frente a
/// la configuración actual (RF-049).
class BuilderCandidate {
  const BuilderCandidate({
    required this.product,
    required this.compatible,
    this.incompatibilityReason,
  });

  final Product product;
  final bool compatible;
  final String? incompatibilityReason;

  bool get inStock => product.stockLevel != StockLevel.outOfStock;
}
