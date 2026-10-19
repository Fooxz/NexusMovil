/// Familias del catálogo: solo computadores armados y piezas (RN-010).
enum ProductFamily { prebuiltPc, part }

/// Los nombres coinciden con `category` del contrato (docs/API_CONTRATO.md).
enum ProductCategory {
  prebuiltPc,
  cpu,
  gpu,
  ram,
  motherboard,
  storage,
  psu,
  pcCase,
  cooling,
}

extension ProductCategoryX on ProductCategory {
  /// Mientras no se decida D8, `prebuiltPc` es la única categoría de su familia.
  ProductFamily get family => this == ProductCategory.prebuiltPc
      ? ProductFamily.prebuiltPc
      : ProductFamily.part;
}

enum StockLevel { stable, critical, outOfStock }

extension StockLevelX on StockLevel {
  String get tagLabel => switch (this) {
    StockLevel.stable => 'ESTABLE',
    StockLevel.critical => 'CRÍTICO',
    StockLevel.outOfStock => 'AGOTADO',
  };

  String get detailLabel => switch (this) {
    StockLevel.outOfStock => 'AGOTADO',
    _ => 'EN STOCK',
  };
}

class ProductSpec {
  const ProductSpec({required this.label, required this.value});

  final String label;
  final String value;
}

/// Lo que un proveedor vende de un producto (RF-014). El precio lo fija el
/// proveedor (RN-001).
class ProductOffer {
  const ProductOffer({
    required this.id,
    required this.providerId,
    required this.providerName,
    required this.priceCents,
    this.oldPriceCents,
    required this.stockLevel,
  });

  final String id;
  final String providerId;
  final String providerName;
  final int priceCents;
  final int? oldPriceCents;
  final StockLevel stockLevel;

  bool get hasDiscount =>
      oldPriceCents != null && oldPriceCents! > priceCents;
}

/// `Product` es lo que vende la tienda. `ProductSpec` es solo texto para mostrar.
/// Los atributos con tipo para compatibilidad van en `PcPartSpec`
/// (`features/pc_builder`, fase 6). No agregar campos de compatibilidad a `Product`.
///
/// `priceCents`, `oldPriceCents` y `stockLevel` son los de la mejor oferta.
/// `offers` solo viene lleno en el detalle; en listas es `[]`.
/// `bestOfferId` es la oferta que se agrega al carrito desde una lista.
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    required this.priceCents,
    this.oldPriceCents,
    required this.stockLevel,
    this.bestOfferId,
    this.imageUrl,
    this.summary,
    this.quickSpecs = const [],
    this.specs = const [],
    this.offers = const [],
  });

  final String id;
  final String name;
  final String brand;
  final ProductCategory category;
  final int priceCents;
  final int? oldPriceCents;
  final StockLevel stockLevel;
  final String? bestOfferId;
  final String? imageUrl;
  final String? summary;
  final List<String> quickSpecs;
  final List<ProductSpec> specs;
  final List<ProductOffer> offers;

  ProductFamily get family => category.family;

  Product copyWith({String? bestOfferId, List<ProductOffer>? offers}) => Product(
    id: id,
    name: name,
    brand: brand,
    category: category,
    priceCents: priceCents,
    oldPriceCents: oldPriceCents,
    stockLevel: stockLevel,
    bestOfferId: bestOfferId ?? this.bestOfferId,
    imageUrl: imageUrl,
    summary: summary,
    quickSpecs: quickSpecs,
    specs: specs,
    offers: offers ?? this.offers,
  );

  bool get hasDiscount =>
      oldPriceCents != null && oldPriceCents! > priceCents;

  int get discountPercent => hasDiscount
      ? ((oldPriceCents! - priceCents) * 100 / oldPriceCents!).round()
      : 0;
}
