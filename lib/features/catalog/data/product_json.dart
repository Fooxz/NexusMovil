import '../domain/catalog_offer.dart';
import '../domain/product.dart';
import '../domain/product_page.dart';

/// Lectura del JSON del contrato (docs/API_CONTRATO.md, sección 2).
///
/// Lanza `FormatException` si falta un campo obligatorio o tiene otro tipo.
/// Los campos desconocidos se ignoran. Un `stockLevel` desconocido se lee como
/// `outOfStock` (no comprable). Un producto con `category` desconocida no se
/// puede mostrar: `productFromJson` devuelve `null` y las listas lo omiten.

ProductPage productPageFromJson(Object? json) {
  if (json case {
    'items': List<Object?> items,
    'total': int total,
    'page': int page,
    'pageSize': int pageSize,
  }) {
    return ProductPage(
      items: productListFromJson(items),
      total: total,
      page: page,
      pageSize: pageSize,
    );
  }
  throw FormatException('Página de productos inválida', json);
}

List<Product> productListFromJson(Object? json) {
  if (json is! List<Object?>) {
    throw FormatException('Lista de productos inválida', json);
  }
  return [for (final item in json) ?productFromJson(item)];
}

Product? productFromJson(Object? json) {
  if (json case {
    'id': String id,
    'name': String name,
    'brand': String brand,
    'category': String categoryName,
    'priceCents': int priceCents,
    'stockLevel': String stockLevelName,
  }) {
    final category = ProductCategory.values.asNameMap()[categoryName];
    if (category == null) return null;

    return Product(
      id: id,
      name: name,
      brand: brand,
      category: category,
      priceCents: priceCents,
      oldPriceCents: _optional<int>(json, 'oldPriceCents'),
      stockLevel: _stockLevel(stockLevelName),
      bestOfferId: _optional<String>(json, 'bestOfferId'),
      imageUrl: _optional<String>(json, 'imageUrl'),
      summary: _optional<String>(json, 'summary'),
      quickSpecs: [
        for (final spec in _list(json, 'quickSpecs'))
          if (spec is String) spec,
      ],
      specs: [
        for (final spec in _list(json, 'specs'))
          if (spec case {'label': String label, 'value': String value})
            ProductSpec(label: label, value: value),
      ],
      offers: [
        for (final offer in _list(json, 'offers')) _offerFromJson(offer),
      ],
    );
  }
  throw FormatException('Producto inválido', json);
}

ProductOffer _offerFromJson(Object? json) {
  if (json case {
    'id': String id,
    'providerId': String providerId,
    'providerName': String providerName,
    'priceCents': int priceCents,
    'stockLevel': String stockLevelName,
  }) {
    return ProductOffer(
      id: id,
      providerId: providerId,
      providerName: providerName,
      priceCents: priceCents,
      oldPriceCents: _optional<int>(json, 'oldPriceCents'),
      stockLevel: _stockLevel(stockLevelName),
    );
  }
  throw FormatException('Oferta inválida', json);
}

/// Página de `get_offers` (API_CONTRATO, parte 6): una tarjeta por oferta.
OfferPage offerPageFromJson(Object? json) {
  if (json case {
    'items': List<Object?> items,
    'total': int total,
    'page': int page,
    'pageSize': int pageSize,
  }) {
    return OfferPage(
      items: [for (final item in items) ?catalogOfferFromJson(item)],
      total: total,
      page: page,
      pageSize: pageSize,
    );
  }
  throw FormatException('Página de ofertas inválida', json);
}

/// Una tarjeta del catálogo, o `null` si su categoría es desconocida.
CatalogOffer? catalogOfferFromJson(Object? json) {
  if (json case {
    'offerId': String offerId,
    'productId': String productId,
    'name': String name,
    'brand': String brand,
    'category': String categoryName,
    'providerId': String providerId,
    'providerName': String providerName,
    'priceCents': int priceCents,
    'stockLevel': String stockLevelName,
  }) {
    final category = ProductCategory.values.asNameMap()[categoryName];
    if (category == null) return null;
    return CatalogOffer(
      offerId: offerId,
      productId: productId,
      name: name,
      brand: brand,
      category: category,
      providerId: providerId,
      providerName: providerName,
      priceCents: priceCents,
      oldPriceCents: _optional<int>(json, 'oldPriceCents'),
      stockLevel: _stockLevel(stockLevelName),
      imageUrl: _optional<String>(json, 'imageUrl'),
      summary: _optional<String>(json, 'summary'),
      quickSpecs: [
        for (final spec in _list(json, 'quickSpecs'))
          if (spec is String) spec,
      ],
      offerCount: _optional<int>(json, 'offerCount') ?? 1,
    );
  }
  throw FormatException('Oferta del catálogo inválida', json);
}

/// Tiendas de `get_catalog_providers`.
List<CatalogStore> catalogStoresFromJson(Object? json) {
  if (json is! List<Object?>) {
    throw FormatException('Lista de tiendas inválida', json);
  }
  return [
    for (final store in json)
      if (store case {
        'id': String id,
        'displayName': String displayName,
        'offerCount': int offerCount,
      })
        CatalogStore(id: id, displayName: displayName, offerCount: offerCount),
  ];
}

StockLevel _stockLevel(String name) =>
    StockLevel.values.asNameMap()[name] ?? StockLevel.outOfStock;

T? _optional<T>(Map<Object?, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is T) return value as T;
  throw FormatException('Campo "$key" con tipo inválido', value);
}

/// Las listas nunca son `null` en el contrato, pero se toleran ausentes.
List<Object?> _list(Map<Object?, Object?> json, String key) =>
    _optional<List<Object?>>(json, key) ?? const [];
