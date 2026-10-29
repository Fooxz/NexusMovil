import '../../catalog/domain/product.dart';

/// Estado de una publicación (oferta). Retirar es lógico: la oferta queda en
/// el historial de órdenes y se puede volver a publicar.
enum OfferStatus { draft, published, paused, retired }

/// Revisión de NEXUS sobre una publicación ya publicada (moderación
/// posterior, API_CONTRATO parte 10): aprobada, oculta hasta que la tienda la
/// corrija, corregida y esperando revisión, o rechazada.
enum OfferModeration {
  approved,
  hidden,
  review,
  rejected;

  String get label => switch (this) {
    approved => 'Aprobada',
    hidden => 'Oculta por NEXUS',
    review => 'En revisión',
    rejected => 'Rechazada por NEXUS',
  };

  static OfferModeration fromName(String? name) => values.asNameMap()[name] ?? approved;
}

/// Una publicación de la tienda en "Mis publicaciones" (API_CONTRATO, parte 8).
class MyOffer {
  const MyOffer({
    required this.offerId,
    required this.productId,
    required this.name,
    required this.brand,
    this.model,
    required this.category,
    this.imageUrl,
    required this.priceCents,
    this.oldPriceCents,
    required this.stockUnits,
    required this.stockLevel,
    required this.status,
    required this.externalSku,
    required this.visible,
    required this.canEditSheet,
    this.moderation = OfferModeration.approved,
    this.moderationReason,
  });

  final String offerId;
  final String productId;
  final String name;
  final String brand;
  final String? model;
  final ProductCategory category;
  final String? imageUrl;
  final int priceCents;

  /// Precio anterior: hay descuento si es mayor que [priceCents].
  final int? oldPriceCents;

  /// Las unidades son de la tienda: a ella sí se le muestran.
  final int stockUnits;
  final StockLevel stockLevel;
  final OfferStatus status;
  final String externalSku;

  /// Se ve en el catálogo: publicada y con la tienda habilitada.
  final bool visible;

  /// La registró esta tienda y ninguna otra la vende: puede editar la ficha.
  final bool canEditSheet;
  final OfferModeration moderation;

  /// Por qué NEXUS la ocultó o la rechazó.
  final String? moderationReason;
}

class ProductImageRef {
  const ProductImageRef({required this.url, this.path});

  final String url;

  /// Ruta en el bucket `product-images`, o null si no se subió desde NEXUS.
  final String? path;
}

/// Publicación con la ficha completa, para editarla.
class MyOfferDetail {
  const MyOfferDetail({
    required this.offer,
    this.summary,
    this.quickSpecs = const [],
    this.specs = const [],
    this.attributes = const {},
    this.images = const [],
    this.sellers = 0,
  });

  final MyOffer offer;
  final String? summary;
  final List<String> quickSpecs;
  final List<ProductSpec> specs;

  /// Atributos técnicos por clave (número, texto, booleano o lista).
  final Map<String, Object?> attributes;
  final List<ProductImageRef> images;

  /// Tiendas con una oferta visible del producto.
  final int sellers;
}

/// Ficha del catálogo para publicar una oferta sobre ella en vez de duplicar
/// el producto.
class CatalogSheet {
  const CatalogSheet({
    required this.productId,
    required this.name,
    required this.brand,
    this.model,
    required this.category,
    this.imageUrl,
    this.sellers = 0,
    this.myOfferStatus,
  });

  final String productId;
  final String name;
  final String brand;
  final String? model;
  final ProductCategory category;
  final String? imageUrl;
  final int sellers;

  /// Estado de la oferta de esta tienda, si ya tiene una.
  final OfferStatus? myOfferStatus;
}

class PortalPage<T> {
  const PortalPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<T> items;
  final int total;
  final int page;
  final int pageSize;

  bool get hasMore => (page + 1) * pageSize < total;
}

/// Tipos de la plantilla de atributos (`attribute_definitions.data_type`).
enum AttributeType { number, text, boolean, choice, choices }

/// Un atributo técnico de la plantilla de una categoría (RN-032).
class AttributeDefinition {
  const AttributeDefinition({
    required this.key,
    required this.label,
    required this.type,
    this.unit,
    this.isRequired = false,
    this.allowedValues = const [],
  });

  final String key;
  final String label;
  final AttributeType type;
  final String? unit;
  final bool isRequired;
  final List<String> allowedValues;
}

/// Datos de la oferta que envía la tienda. Los precios van en centavos de
/// COP y en pesos enteros (múltiplos de 100).
class OfferInput {
  const OfferInput({
    required this.priceCents,
    this.oldPriceCents,
    required this.stockUnits,
    this.status = OfferStatus.published,
    this.externalSku,
  });

  final int priceCents;
  final int? oldPriceCents;
  final int stockUnits;

  /// Borrador, publicada o pausada. Retirar tiene su propia acción.
  final OfferStatus status;
  final String? externalSku;

  Map<String, Object?> toJson() => {
    'priceCents': priceCents,
    'oldPriceCents': oldPriceCents,
    'stockUnits': stockUnits,
    'status': status.name,
    if (externalSku != null && externalSku!.trim().isNotEmpty) 'externalSku': externalSku!.trim(),
  };
}

/// Datos de la ficha que envía la tienda. [images] son rutas del bucket.
class ProductInput {
  const ProductInput({
    required this.category,
    required this.name,
    required this.brand,
    required this.model,
    this.summary,
    this.quickSpecs = const [],
    this.specs = const [],
    this.attributes = const {},
    this.images = const [],
  });

  final ProductCategory category;
  final String name;
  final String brand;
  final String model;
  final String? summary;
  final List<String> quickSpecs;
  final List<ProductSpec> specs;
  final Map<String, Object?> attributes;
  final List<String> images;

  Map<String, Object?> toJson() => {
    'category': category.name,
    'name': name.trim(),
    'brand': brand.trim(),
    'model': model.trim(),
    if (summary != null && summary!.trim().isNotEmpty) 'summary': summary!.trim(),
    'quickSpecs': quickSpecs,
    'specs': [
      for (final spec in specs) {'label': spec.label, 'value': spec.value},
    ],
    'attributes': attributes,
    'images': images,
  };
}
