import 'product.dart';

/// Orden del listado. Los nombres coinciden con `sort` del contrato.
/// `relevance` ordena por nombre mientras no exista un puntaje de búsqueda.
enum ProductSort { relevance, priceAsc, priceDesc }

/// Criterios de búsqueda y filtrado del catálogo (RF-032, RF-033).
class ProductFilters {
  const ProductFilters({
    this.search = '',
    this.category,
    this.brand,
    this.providerId,
    this.minPriceCents,
    this.maxPriceCents,
    this.sort = ProductSort.relevance,
  });

  final String search;
  final ProductCategory? category;
  final String? brand;

  /// Tienda (id) del catálogo por oferta. `getProducts` lo ignora.
  final String? providerId;
  final int? minPriceCents;
  final int? maxPriceCents;
  final ProductSort sort;

  /// El orden no cuenta como filtro: "Limpiar filtros" lo conserva.
  bool get hasActiveFilters =>
      search.isNotEmpty ||
      category != null ||
      brand != null ||
      providerId != null ||
      minPriceCents != null ||
      maxPriceCents != null;

  static const _unset = Object();

  /// Los parámetros anulables usan un centinela para distinguir "no cambiar"
  /// de "quitar el filtro" (`null`).
  ProductFilters copyWith({
    String? search,
    Object? category = _unset,
    Object? brand = _unset,
    Object? providerId = _unset,
    Object? minPriceCents = _unset,
    Object? maxPriceCents = _unset,
    ProductSort? sort,
  }) {
    return ProductFilters(
      search: search ?? this.search,
      category: identical(category, _unset)
          ? this.category
          : category as ProductCategory?,
      brand: identical(brand, _unset) ? this.brand : brand as String?,
      providerId: identical(providerId, _unset)
          ? this.providerId
          : providerId as String?,
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
      other.category == category &&
      other.brand == brand &&
      other.providerId == providerId &&
      other.minPriceCents == minPriceCents &&
      other.maxPriceCents == maxPriceCents &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(
    search,
    category,
    brand,
    providerId,
    minPriceCents,
    maxPriceCents,
    sort,
  );
}
