import 'product.dart';

/// Una tarjeta del catálogo: la oferta de UNA tienda para un producto
/// (API_CONTRATO, parte 6). Si tres tiendas venden la misma pieza, hay tres
/// tarjetas, cada una con su precio, su descuento y su stock.
class CatalogOffer {
  const CatalogOffer({
    required this.offerId,
    required this.productId,
    required this.name,
    required this.brand,
    required this.category,
    required this.providerId,
    required this.providerName,
    required this.priceCents,
    this.oldPriceCents,
    required this.stockLevel,
    this.imageUrl,
    this.summary,
    this.quickSpecs = const [],
    this.offerCount = 1,
  });

  final String offerId;
  final String productId;
  final String name;
  final String brand;
  final ProductCategory category;
  final String providerId;

  /// Nombre visible de la tienda que vende.
  final String providerName;
  final int priceCents;
  final int? oldPriceCents;
  final StockLevel stockLevel;
  final String? imageUrl;
  final String? summary;
  final List<String> quickSpecs;

  /// Cuántas tiendas venden el producto: con más de una se puede comparar.
  final int offerCount;

  bool get hasDiscount => oldPriceCents != null && oldPriceCents! > priceCents;

  int get discountPercent => hasDiscount
      ? ((oldPriceCents! - priceCents) * 100 / oldPriceCents!).round()
      : 0;
}

class OfferPage {
  const OfferPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<CatalogOffer> items;
  final int total;
  final int page;
  final int pageSize;

  bool get hasMore => (page + 1) * pageSize < total;
}

/// Tienda con ofertas visibles, para el filtro por tienda. Se filtra por
/// [id]: dos tiendas distintas pueden tener el mismo nombre visible.
class CatalogStore {
  const CatalogStore({
    required this.id,
    required this.displayName,
    required this.offerCount,
  });

  final String id;
  final String displayName;
  final int offerCount;
}
