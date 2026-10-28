import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/network/supabase_rpc.dart';
import '../../catalog/domain/product.dart';
import '../domain/portal_models.dart';
import '../domain/portal_repository.dart';
import 'portal_json.dart';

/// Filas de `attribute_definitions` de una categoría, ordenadas.
typedef TemplateLoader = Future<List<Object?>> Function(String category);

/// Sube un archivo al bucket `product-images` sin reemplazar (la política de
/// Storage tampoco lo permite).
typedef ImageUploader =
    Future<void> Function(String path, Uint8List bytes, String contentType);

/// Publicaciones de la tienda: RPC de la parte 8, la plantilla de atributos
/// (tabla pública) y Storage.
class SupabasePortalRepository implements ProviderPortalRepository {
  SupabasePortalRepository(
    this._rpc, {
    required this.loadTemplate,
    required this.upload,
  });

  factory SupabasePortalRepository.fromClient(SupabaseClient client) =>
      SupabasePortalRepository(
        supabaseRpc(client),
        loadTemplate: (category) => client
            .from('attribute_definitions')
            .select('key, label, data_type, unit, is_required, allowed_values, sort_order')
            .eq('category_code', category)
            .order('sort_order'),
        upload: (path, bytes, contentType) => client.storage
            .from('product-images')
            .uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(contentType: contentType, upsert: false),
            ),
      );

  final SupabaseRpc _rpc;
  final TemplateLoader loadTemplate;
  final ImageUploader upload;

  Future<MyOfferDetail> _detail(String function, Map<String, Object?> params) async {
    final json = await guardedRpc(_rpc, function, params);
    return parseResponse(() => myOfferDetailFromJson(json));
  }

  @override
  Future<PortalPage<MyOffer>> getMyOffers({
    OfferStatus? status,
    String search = '',
    int page = 0,
    int pageSize = 20,
  }) async {
    final json = await guardedRpc(_rpc, 'get_my_offers', {
      if (status != null) 'status': status.name,
      if (search.trim().isNotEmpty) 'search': search.trim(),
      'page': page,
      'page_size': pageSize,
    });
    return parseResponse(() => portalPageFromJson(json, myOfferFromJson));
  }

  @override
  Future<MyOfferDetail> getMyOffer(String productId) =>
      _detail('get_my_offer', {'product_id': productId});

  @override
  Future<PortalPage<CatalogSheet>> searchSheets({
    String search = '',
    ProductCategory? category,
    int page = 0,
  }) async {
    final json = await guardedRpc(_rpc, 'search_catalog_sheets', {
      if (search.trim().isNotEmpty) 'search': search.trim(),
      if (category != null) 'category': category.name,
      'page': page,
    });
    return parseResponse(() => portalPageFromJson(json, catalogSheetFromJson));
  }

  @override
  Future<MyOfferDetail> createProduct(
    ProductInput product,
    OfferInput offer, {
    bool confirmDistinct = false,
  }) => _detail('create_my_product', {
    'product': product.toJson(),
    'offer': offer.toJson(),
    'confirm_distinct': confirmDistinct,
  });

  @override
  Future<MyOfferDetail> updateProduct(String productId, ProductInput product) =>
      _detail('update_my_product', {'product_id': productId, 'product': product.toJson()});

  @override
  Future<MyOfferDetail> createOffer(String productId, OfferInput offer) =>
      _detail('create_my_offer', {'product_id': productId, 'offer': offer.toJson()});

  @override
  Future<MyOfferDetail> updateOffer(String productId, OfferInput offer) =>
      _detail('update_my_offer', {'product_id': productId, 'offer': offer.toJson()});

  @override
  Future<MyOfferDetail> retireOffer(String productId) =>
      _detail('retire_my_offer', {'product_id': productId});

  @override
  Future<List<AttributeDefinition>> getAttributeTemplate(ProductCategory category) async {
    final List<Object?> rows;
    try {
      rows = await loadTemplate(category.name);
    } on PostgrestException catch (error) {
      throw AppFailure.fromApiError(code: error.code);
    } on Exception {
      throw const NetworkFailure();
    }
    return parseResponse(() => [for (final row in rows) attributeDefinitionFromJson(row)]);
  }

  @override
  Future<String> uploadImage({
    required String storeId,
    required Uint8List bytes,
    required String extension,
    required String contentType,
  }) async {
    final path = '$storeId/${randomImageName()}.$extension';
    try {
      await upload(path, bytes, contentType);
    } on StorageException catch (error) {
      // 403: la política no deja subir (tienda no habilitada o carpeta ajena).
      throw error.statusCode == '403' || error.statusCode == '401'
          ? const ForbiddenFailure()
          : const UnexpectedFailure();
    } on Exception {
      throw const NetworkFailure();
    }
    return path;
  }
}

final _random = Random.secure();

/// Nombre aleatorio para una imagen (32 caracteres hexadecimales).
String randomImageName() =>
    List.generate(16, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
