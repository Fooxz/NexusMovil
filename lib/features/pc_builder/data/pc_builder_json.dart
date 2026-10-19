import '../../catalog/data/product_json.dart';
import '../../catalog/domain/product.dart';
import '../domain/pc_builder_models.dart';

/// Lectura del JSON de las RPC del armador (API_CONTRATO, parte 3).
/// Lanza `FormatException` si falta un campo obligatorio. Las ranuras y piezas
/// de categorías desconocidas se omiten.

ProductCategory? _category(Object? name) =>
    name is String ? ProductCategory.values.asNameMap()[name] : null;

List<BuilderSlot> builderSlotsFromJson(Object? json) {
  if (json is! List<Object?>) throw FormatException('Ranuras inválidas', json);
  return [for (final slot in json) ?_slotFromJson(slot)];
}

BuilderSlot? _slotFromJson(Object? json) {
  if (json case {'category': String name, 'label': String label}) {
    final category = _category(name);
    if (category == null) return null;
    return BuilderSlot(
      category: category,
      label: label,
      required: json['required'] == true,
    );
  }
  throw FormatException('Ranura inválida', json);
}

BuildValidation buildValidationFromJson(Object? json) {
  if (json case {
    'valid': bool valid,
    'purchasable': bool purchasable,
    'parts': List<Object?> parts,
    'issues': List<Object?> issues,
    'missingSlots': List<Object?> missing,
    'totalCents': int totalCents,
  }) {
    return BuildValidation(
      valid: valid,
      purchasable: purchasable,
      parts: [for (final part in parts) ?_partFromJson(part)],
      issues: [for (final issue in issues) _issueFromJson(issue)],
      missingSlots: [
        for (final slot in missing)
          if (slot case {'category': String name, 'label': String label})
            if (_category(name) case final category?)
              BuilderSlot(category: category, label: label, required: true),
      ],
      totalCents: totalCents,
    );
  }
  throw FormatException('Validación inválida', json);
}

BuildPart? _partFromJson(Object? json) {
  if (json case {
    'offerId': String offerId,
    'category': String categoryName,
    'productId': String productId,
    'productName': String productName,
    'brand': String brand,
    'providerName': String providerName,
    'priceCents': int priceCents,
    'available': bool available,
  }) {
    final category = _category(categoryName);
    if (category == null) return null;
    final imageUrl = json['imageUrl'];
    return BuildPart(
      offerId: offerId,
      category: category,
      productId: productId,
      productName: productName,
      brand: brand,
      providerName: providerName,
      priceCents: priceCents,
      isAvailable: available,
      imageUrl: imageUrl is String ? imageUrl : null,
    );
  }
  throw FormatException('Pieza inválida', json);
}

BuildIssue _issueFromJson(Object? json) {
  if (json case {
    'ruleCode': String ruleCode,
    'severity': String severity,
    'message': String message,
    'offerIds': List<Object?> offerIds,
  }) {
    return BuildIssue(
      ruleCode: ruleCode,
      // Una severidad desconocida se trata como error: es lo más prudente.
      severity: severity == 'warning' ? IssueSeverity.warning : IssueSeverity.error,
      message: message,
      offerIds: [for (final id in offerIds) if (id is String) id],
    );
  }
  throw FormatException('Aviso de compatibilidad inválido', json);
}

List<BuilderCandidate> builderCandidatesFromJson(Object? json) {
  if (json is! List<Object?>) throw FormatException('Candidatos inválidos', json);
  return [
    for (final item in json)
      if (productFromJson(item) case final product?)
        BuilderCandidate(
          product: product,
          compatible: (item as Map)['compatible'] != false,
          incompatibilityReason: item['incompatibilityReason'] as String?,
        ),
  ];
}
