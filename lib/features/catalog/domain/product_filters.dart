import 'product.dart';

/// Orden del listado. Los nombres coinciden con `sort` del contrato.
/// `relevance` ordena por nombre mientras no exista un puntaje de búsqueda.
enum ProductSort { relevance, priceAsc, priceDesc }

/// Criterios de búsqueda y filtrado del catálogo (RF-032, RF-033).
class ProductFilters {
  const ProductFilters({
    this.search = '',
    this.family,
    this.category,
    this.brand,
    this.minPriceCents,
    this.maxPriceCents,
    this.sort = ProductSort.relevance,
  });

  final String search;
  final ProductFamily? family;
  final ProductCategory? category;
  final String? brand;
  final int? minPriceCents;
  final int? maxPriceCents;
  final ProductSort sort;

  /// El orden no cuenta como filtro: "Limpiar filtros" lo conserva.
  bool get hasActiveFilters =>
      search.isNotEmpty ||
      family != null ||
      category != null ||
      brand != null ||
      minPriceCents != null ||
      maxPriceCents != null;

  static const _unset = Object();

  /// Los parámetros anulables usan un centinela para distinguir "no cambiar"
  /// de "quitar el filtro" (`null`).
  ProductFilters copyWith({
    String? search,
    Object? family = _unset,
    Object? category = _unset,
    Object? brand = _unset,
    Object? minPriceCents = _unset,
    Object? maxPriceCents = _unset,
    ProductSort? sort,
  }) {
    return ProductFilters(
      search: search ?? this.search,
      family: identical(family, _unset) ? this.family : family as ProductFamily?,
      category: identical(category, _unset)
          ? this.category
          : category as ProductCategory?,
      brand: identical(brand, _unset) ? this.brand : brand as String?,
      minPriceCents: identical(minPriceCents, _unset)
          ? this.minPriceCents
          : minPriceCents as int?,
      maxPriceCents: identical(maxPriceCents, _unset)
          ? this.maxPriceCents
          : maxPriceCents as int?,
      sort: sort ?? this.sort,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ProductFilters &&
      other.search == search &&
      other.family == family &&
      other.category == category &&
      other.brand == brand &&
      other.minPriceCents == minPriceCents &&
      other.maxPriceCents == maxPriceCents &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(
    search,
    family,
    category,
    brand,
    minPriceCents,
    maxPriceCents,
    sort,
  );
}
