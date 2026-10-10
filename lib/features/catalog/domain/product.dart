enum ProductCategory {
  phone,
  cpu,
  gpu,
  ram,
  motherboard,
  storage,
  psu,
  pcCase,
  cooling,
}

enum StockLevel { stable, critical }

class ProductSpec {
  const ProductSpec({required this.label, required this.value});

  final String label;
  final String value;
}

/// `Product` es lo que vende la tienda. `ProductSpec` es solo texto para mostrar.
/// Los atributos con tipo para compatibilidad van en `PcPartSpec`
/// (`features/pc_builder`, paso 7). No agregar campos de compatibilidad a `Product`.
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    required this.priceCents,
    this.oldPriceCents,
    required this.stockLevel,
    this.summary,
    this.quickSpecs = const [],
    this.specs = const [],
  });

  final String id;
  final String name;
  final String brand;
  final ProductCategory category;
  final int priceCents;
  final int? oldPriceCents;
  final StockLevel stockLevel;
  final String? summary;
  final List<String> quickSpecs;
  final List<ProductSpec> specs;

  bool get hasDiscount =>
      oldPriceCents != null && oldPriceCents! > priceCents;

  int get discountPercent => hasDiscount
      ? ((oldPriceCents! - priceCents) * 100 / oldPriceCents!).round()
      : 0;
}
