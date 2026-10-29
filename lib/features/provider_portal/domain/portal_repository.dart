import 'dart:typed_data';

import '../../catalog/domain/product.dart';
import 'portal_models.dart';

/// Publicaciones de la tienda con sesión (API_CONTRATO, parte 8). El backend
/// sabe de qué tienda es la cuenta: ningún método recibe el id de la tienda,
/// salvo la ruta de las imágenes, que Storage valida. Los errores llegan como
/// `AppFailure`.
abstract class ProviderPortalRepository {
  /// Sin [status], todas menos las retiradas.
  Future<PortalPage<MyOffer>> getMyOffers({
    OfferStatus? status,
    String search = '',
    int page = 0,
    int pageSize = 20,
  });

  Future<MyOfferDetail> getMyOffer(String productId);

  /// Fichas del catálogo, tengan o no ofertas visibles.
  Future<PortalPage<CatalogSheet>> searchSheets({
    String search = '',
    ProductCategory? category,
    int page = 0,
  });

  /// Registra un producto nuevo con su oferta. Se publica sin aprobación.
  Future<MyOfferDetail> createProduct(
    ProductInput product,
    OfferInput offer, {
    bool confirmDistinct = false,
  });

  /// Edita la ficha (solo si la registró la tienda y nadie más la vende).
  Future<MyOfferDetail> updateProduct(String productId, ProductInput product);

  /// Publica la oferta sobre un producto existente (o reactiva la retirada).
  Future<MyOfferDetail> createOffer(String productId, OfferInput offer);

  Future<MyOfferDetail> updateOffer(String productId, OfferInput offer);

  Future<MyOfferDetail> retireOffer(String productId);

  /// La tienda corrigió una publicación oculta por NEXUS y pide que la
  /// revisen. `NotHiddenFailure` si no está oculta.
  Future<MyOfferDetail> requestReview(String productId);

  /// Plantilla de atributos técnicos de la categoría.
  Future<List<AttributeDefinition>> getAttributeTemplate(ProductCategory category);

  /// Sube una imagen a la carpeta de la tienda y devuelve su ruta en el
  /// bucket, para enviarla en [ProductInput.images].
  Future<String> uploadImage({
    required String storeId,
    required Uint8List bytes,
    required String extension,
    required String contentType,
  });
}
