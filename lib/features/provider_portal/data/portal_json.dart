import '../../catalog/domain/product.dart';
import '../domain/portal_models.dart';

/// Lectura de las RPC de la tienda (API_CONTRATO, parte 8). Lanza
/// `FormatException` si falta un campo obligatorio.

OfferStatus offerStatusFromName(String name) =>
    OfferStatus.values.asNameMap()[name] ?? OfferStatus.paused;

ProductCategory _category(String name, Object? json) =>
    ProductCategory.values.asNameMap()[name] ??
    (throw FormatException('Categoría desconocida', json));

StockLevel _stockLevel(String name) =>
    StockLevel.values.asNameMap()[name] ?? StockLevel.outOfStock;

String? _string(Map<Object?, Object?> json, String key) =>
    json[key] is String ? json[key] as String : null;

MyOffer myOfferFromJson(Object? json) {
  if (json case {
    'offerId': String offerId,
    'productId': String productId,
    'name': String name,
    'brand': String brand,
    'category': String category,
    'priceCents': int priceCents,
    'stockUnits': int stockUnits,
    'stockLevel': String stockLevel,
    'status': String status,
    'externalSku': String externalSku,
    'visible': bool visible,
    'canEditSheet': bool canEditSheet,
  }) {
    return MyOffer(
      offerId: offerId,
      productId: productId,
      name: name,
      brand: brand,
      model: _string(json, 'model'),
      category: _category(category, json),
      imageUrl: _string(json, 'imageUrl'),
      priceCents: priceCents,
      oldPriceCents: json['oldPriceCents'] is int ? json['oldPriceCents'] as int : null,
      stockUnits: stockUnits,
      stockLevel: _stockLevel(stockLevel),
      status: offerStatusFromName(status),
      externalSku: externalSku,
      visible: visible,
      canEditSheet: canEditSheet,
      moderation: OfferModeration.fromName(_string(json, 'moderationStatus')),
      moderationReason: _string(json, 'moderationReason'),
    );
  }
  throw FormatException('Publicación inválida', json);
}

MyOfferDetail myOfferDetailFromJson(Object? json) {
  if (json is! Map<Object?, Object?>) throw FormatException('Publicación inválida', json);
  final quickSpecs = json['quickSpecs'];
  final specs = json['specs'];
  final attributes = json['attributes'];
  final images = json['images'];
  return MyOfferDetail(
    offer: myOfferFromJson(json),
    summary: _string(json, 'summary'),
    quickSpecs: [
      if (quickSpecs is List)
        for (final spec in quickSpecs)
          if (spec is String) spec,
    ],
    specs: [
      if (specs is List)
        for (final spec in specs)
          if (spec case {'label': String label, 'value': String value})
            ProductSpec(label: label, value: value),
    ],
    attributes: attributes is Map
        ? {for (final entry in attributes.entries) '${entry.key}': entry.value}
        : const {},
    images: [
      if (images is List)
        for (final image in images)
          if (image case {'url': String url})
            ProductImageRef(url: url, path: image['path'] is String ? image['path'] as String : null),
    ],
    sellers: json['sellers'] is int ? json['sellers'] as int : 0,
  );
}

PortalPage<T> portalPageFromJson<T>(Object? json, T Function(Object?) item) {
  if (json case {
    'items': List<Object?> items,
    'total': int total,
    'page': int page,
    'pageSize': int pageSize,
  }) {
    return PortalPage(
      items: [for (final entry in items) item(entry)],
      total: total,
      page: page,
      pageSize: pageSize,
    );
  }
  throw FormatException('Página inválida', json);
}

CatalogSheet catalogSheetFromJson(Object? json) {
  if (json case {
    'productId': String productId,
    'name': String name,
    'brand': String brand,
    'category': String category,
  }) {
    return CatalogSheet(
      productId: productId,
      name: name,
      brand: brand,
      model: _string(json, 'model'),
      category: _category(category, json),
      imageUrl: _string(json, 'imageUrl'),
      sellers: json['sellers'] is int ? json['sellers'] as int : 0,
      myOfferStatus: _myOfferStatus(json['myOffer']),
    );
  }
  throw FormatException('Ficha inválida', json);
}

OfferStatus? _myOfferStatus(Object? json) => switch (json) {
  {'status': final String status} => offerStatusFromName(status),
  _ => null,
};

/// Una fila de `attribute_definitions`.
AttributeDefinition attributeDefinitionFromJson(Object? json) {
  if (json case {
    'key': String key,
    'label': String label,
    'data_type': String dataType,
  }) {
    final allowed = json['allowed_values'];
    return AttributeDefinition(
      key: key,
      label: label,
      type: switch (dataType) {
        'number' => AttributeType.number,
        'boolean' => AttributeType.boolean,
        'enum' => AttributeType.choice,
        'enumList' => AttributeType.choices,
        _ => AttributeType.text,
      },
      unit: _string(json, 'unit'),
      isRequired: json['is_required'] == true,
      allowedValues: [
        if (allowed is List)
          for (final value in allowed)
            if (value is String) value,
      ],
    );
  }
  throw FormatException('Atributo inválido', json);
}
