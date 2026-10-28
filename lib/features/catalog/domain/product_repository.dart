import 'catalog_offer.dart';
import 'product.dart';
import 'product_filters.dart';
import 'product_page.dart';

/// Los errores llegan como `AppFailure` (`core/errors/app_failure.dart`).
abstract class ProductRepository {
  /// Catálogo principal: una tarjeta por oferta de cada tienda (parte 6).
  Future<OfferPage> getOffers({
    int page = 0,
    int pageSize = 20,
    ProductFilters filters = const ProductFilters(),
  });

  /// Tiendas con ofertas visibles, de una categoría o de todas.
  Future<List<CatalogStore>> getStores({ProductCategory? category});

  /// Productos con su mejor oferta. Los usan el detalle, el PC Builder y el
  /// asistente, que no cambian con el catálogo por oferta.
  Future<ProductPage> getProducts({
    int page = 0,
    int pageSize = 20,
    ProductFilters filters = const ProductFilters(),
  });

  /// `null` si el producto no existe o no está visible.
  Future<Product?> getById(String id);

  Future<List<Product>> getRelated(String id, {int limit = 2});

  /// Marcas con productos visibles, de una categoría o de todas.
  Future<List<String>> getBrands({ProductCategory? category});
}
