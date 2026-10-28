import 'dart:typed_data';

import '../../../core/errors/app_failure.dart';
import '../../account/data/mock_directory.dart';
import '../../account/domain/account_models.dart';
import '../../auth/data/mock_auth_repository.dart';
import '../../catalog/data/mock_product_repository.dart';
import '../../catalog/domain/product.dart';
import '../domain/portal_models.dart';
import '../domain/portal_repository.dart';
import 'mock_attribute_templates.dart';

class _Sheet {
  _Sheet({
    required this.id,
    required this.category,
    required this.name,
    required this.brand,
    required this.model,
    this.createdBy,
  });

  final String id;
  final ProductCategory category;
  String name;
  String brand;
  String model;
  String? summary;
  List<String> quickSpecs = const [];
  List<ProductSpec> specs = const [];
  Map<String, Object?> attributes = const {};
  List<String> images = const [];

  /// Tienda que la registró. Null: catálogo base.
  final String? createdBy;
}

class _Offer {
  _Offer({required this.id, required this.input});

  final String id;
  OfferInput input;
  var retired = false;

  OfferStatus get status => retired ? OfferStatus.retired : input.status;
}

/// Publicaciones en memoria para usar el portal sin backend. Aplica las
/// reglas de las RPC de la parte 8: tienda que puede operar, plantilla de
/// atributos, precio en pesos enteros, duplicados, ficha editable solo por
/// quien la registró mientras nadie más la venda y retiro lógico. El catálogo
/// base sale del `MockProductRepository` y no se puede editar. Las imágenes
/// quedan en memoria (sin URL: se muestra el ícono de la categoría).
class MockPortalRepository implements ProviderPortalRepository {
  MockPortalRepository(
    this._auth,
    this._directory,
    this._catalog, {
    this.latency = const Duration(milliseconds: 200),
  });

  final MockAuthRepository _auth;
  final MockDirectory _directory;
  final MockProductRepository _catalog;
  final Duration latency;

  final _sheets = <String, _Sheet>{};

  /// Por tienda y producto.
  final _offers = <String, Map<String, _Offer>>{};
  final uploadedImages = <String, Uint8List>{};
  var _nextId = 1;

  Future<void> _simulateLatency() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  /// Como `private.require_active_provider`.
  MockStore _readyStore() {
    final user = _auth.currentUser;
    if (user == null) throw const UnauthorizedFailure();
    final store = _directory.storeOf(user.id);
    if (_directory.roles[user.id] != AccountRole.provider || store == null) {
      throw const ForbiddenFailure();
    }
    if (store.status != StoreStatus.active) throw const StoreNotActiveFailure();
    if (_directory.provisioned.contains(user.id)) {
      if (!_auth.hasChangedPassword(user.id)) throw const PasswordChangeRequiredFailure();
      if (!_directory.acceptedDocuments.contains(user.id)) throw const DocumentsPendingFailure();
    }
    return store;
  }

  /// Fichas: las del catálogo base y las registradas por tiendas.
  List<_Sheet> _allSheets() => [
    for (final category in ProductCategory.values)
      for (final product in _catalog.productsIn(category))
        _sheets[product.id] ??
            (_Sheet(
                id: product.id,
                category: product.category,
                name: product.name,
                brand: product.brand,
                model: product.name,
              )
              ..summary = product.summary
              ..quickSpecs = product.quickSpecs
              ..specs = product.specs),
    for (final sheet in _sheets.values)
      if (sheet.createdBy != null) sheet,
  ];

  _Sheet? _sheet(String productId) {
    for (final sheet in _allSheets()) {
      if (sheet.id == productId) return sheet;
    }
    return null;
  }

  bool _editable(_Sheet sheet, String storeId) =>
      sheet.createdBy == storeId &&
      !_offers.entries.any((entry) => entry.key != storeId && entry.value.containsKey(sheet.id));

  static StockLevel _stockLevel(int units) => units <= 0
      ? StockLevel.outOfStock
      : units <= 5
      ? StockLevel.critical
      : StockLevel.stable;

  MyOffer _myOffer(MockStore store, _Sheet sheet, _Offer offer) => MyOffer(
    offerId: offer.id,
    productId: sheet.id,
    name: sheet.name,
    brand: sheet.brand,
    model: sheet.model,
    category: sheet.category,
    priceCents: offer.input.priceCents,
    oldPriceCents: offer.input.oldPriceCents,
    stockUnits: offer.input.stockUnits,
    stockLevel: _stockLevel(offer.input.stockUnits),
    status: offer.status,
    externalSku: offer.input.externalSku ?? sheet.id,
    visible: offer.status == OfferStatus.published && store.status == StoreStatus.active,
    canEditSheet: _editable(sheet, store.id),
  );

  MyOfferDetail _detail(MockStore store, String productId) {
    final sheet = _sheet(productId);
    final offer = _offers[store.id]?[productId];
    if (sheet == null || offer == null) throw const NotFoundFailure();
    return MyOfferDetail(
      offer: _myOffer(store, sheet, offer),
      summary: sheet.summary,
      quickSpecs: sheet.quickSpecs,
      specs: sheet.specs,
      attributes: sheet.attributes,
      images: [for (final path in sheet.images) ProductImageRef(url: '', path: path)],
      sellers: _offers.values
          .where((offers) => offers[productId]?.status == OfferStatus.published)
          .length,
    );
  }

  @override
  Future<PortalPage<MyOffer>> getMyOffers({
    OfferStatus? status,
    String search = '',
    int page = 0,
    int pageSize = 20,
  }) async {
    await _simulateLatency();
    final store = _readyStore();
    final query = search.trim().toLowerCase();
    final matches = [
      for (final entry in (_offers[store.id] ?? const <String, _Offer>{}).entries)
        if (_sheet(entry.key) case final sheet?)
          if ((status == null ? entry.value.status != OfferStatus.retired : entry.value.status == status) &&
              (query.isEmpty ||
                  sheet.name.toLowerCase().contains(query) ||
                  sheet.brand.toLowerCase().contains(query)))
            _myOffer(store, sheet, entry.value),
    ].reversed.toList();
    return PortalPage(
      items: matches.skip(page * pageSize).take(pageSize).toList(),
      total: matches.length,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<MyOfferDetail> getMyOffer(String productId) async {
    await _simulateLatency();
    return _detail(_readyStore(), productId);
  }

  @override
  Future<PortalPage<CatalogSheet>> searchSheets({
    String search = '',
    ProductCategory? category,
    int page = 0,
  }) async {
    await _simulateLatency();
    final store = _readyStore();
    final query = search.trim().toLowerCase();
    final matches = [
      for (final sheet in _allSheets())
        if ((category == null || sheet.category == category) &&
            (query.isEmpty ||
                sheet.name.toLowerCase().contains(query) ||
                sheet.brand.toLowerCase().contains(query) ||
                sheet.model.toLowerCase().contains(query)))
          CatalogSheet(
            productId: sheet.id,
            name: sheet.name,
            brand: sheet.brand,
            model: sheet.model,
            category: sheet.category,
            sellers: _offers.values.where((offers) => offers[sheet.id]?.status == OfferStatus.published).length,
            myOfferStatus: _offers[store.id]?[sheet.id]?.status,
          ),
    ];
    const pageSize = 20;
    return PortalPage(
      items: matches.skip(page * pageSize).take(pageSize).toList(),
      total: matches.length,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<MyOfferDetail> createProduct(
    ProductInput product,
    OfferInput offer, {
    bool confirmDistinct = false,
  }) async {
    await _simulateLatency();
    final store = _readyStore();
    _validateProduct(product, store);
    _validateOffer(offer);
    _checkDuplicates(product, null, confirmDistinct: confirmDistinct);

    final id = 'mock-store-product-${_nextId++}';
    _sheets[id] = _apply(
      _Sheet(
        id: id,
        category: product.category,
        name: product.name.trim(),
        brand: product.brand.trim(),
        model: product.model.trim(),
        createdBy: store.id,
      ),
      product,
    );
    (_offers[store.id] ??= {})[id] = _Offer(id: 'mock-offer-${_nextId++}', input: offer);
    return _detail(store, id);
  }

  @override
  Future<MyOfferDetail> updateProduct(String productId, ProductInput product) async {
    await _simulateLatency();
    final store = _readyStore();
    final sheet = _sheet(productId);
    if (sheet == null || _offers[store.id]?[productId] == null) throw const NotFoundFailure();
    if (sheet.createdBy != store.id) throw const ProductLockedFailure();
    if (!_editable(sheet, store.id)) throw const ProductSharedFailure();
    _validateProduct(product, store, category: sheet.category);
    _checkDuplicates(product, productId, confirmDistinct: true);
    _apply(sheet, product)
      ..name = product.name.trim()
      ..brand = product.brand.trim()
      ..model = product.model.trim();
    return _detail(store, productId);
  }

  @override
  Future<MyOfferDetail> createOffer(String productId, OfferInput offer) async {
    await _simulateLatency();
    final store = _readyStore();
    if (_sheet(productId) == null) throw const NotFoundFailure();
    _validateOffer(offer);
    final offers = _offers[store.id] ??= {};
    final existing = offers[productId];
    if (existing != null && !existing.retired) throw const OfferExistsFailure();
    if (existing != null) {
      existing
        ..retired = false
        ..input = offer;
    } else {
      offers[productId] = _Offer(id: 'mock-offer-${_nextId++}', input: offer);
    }
    return _detail(store, productId);
  }

  @override
  Future<MyOfferDetail> updateOffer(String productId, OfferInput offer) async {
    await _simulateLatency();
    final store = _readyStore();
    final existing = _offers[store.id]?[productId];
    if (existing == null) throw const NotFoundFailure();
    if (existing.retired) throw const OfferRetiredFailure();
    _validateOffer(offer);
    existing.input = offer;
    return _detail(store, productId);
  }

  @override
  Future<MyOfferDetail> retireOffer(String productId) async {
    await _simulateLatency();
    final store = _readyStore();
    final existing = _offers[store.id]?[productId];
    if (existing == null) throw const NotFoundFailure();
    existing.retired = true;
    return _detail(store, productId);
  }

  @override
  Future<List<AttributeDefinition>> getAttributeTemplate(ProductCategory category) async {
    await _simulateLatency();
    return mockAttributeTemplates[category] ?? const [];
  }

  @override
  Future<String> uploadImage({
    required String storeId,
    required Uint8List bytes,
    required String extension,
    required String contentType,
  }) async {
    await _simulateLatency();
    if (_readyStore().id != storeId) throw const ForbiddenFailure();
    final path = '$storeId/mock-image-${_nextId++}.$extension';
    uploadedImages[path] = bytes;
    return path;
  }

  _Sheet _apply(_Sheet sheet, ProductInput product) => sheet
    ..summary = product.summary
    ..quickSpecs = product.quickSpecs
    ..specs = product.specs
    ..attributes = Map.of(product.attributes)
    ..images = List.of(product.images);

  void _validateProduct(ProductInput product, MockStore store, {ProductCategory? category}) {
    if (product.name.trim().length < 3) {
      throw const FieldValidationFailure(field: 'name', message: 'El nombre debe tener de 3 a 160 caracteres');
    }
    if (product.brand.trim().isEmpty) {
      throw const FieldValidationFailure(field: 'brand', message: 'La marca es obligatoria (hasta 60 caracteres)');
    }
    if (product.model.trim().isEmpty) {
      throw const FieldValidationFailure(field: 'model', message: 'El modelo es obligatorio (hasta 80 caracteres)');
    }
    for (final definition in mockAttributeTemplates[category ?? product.category] ?? const <AttributeDefinition>[]) {
      final value = product.attributes[definition.key];
      if (value == null) {
        if (definition.isRequired) {
          throw FieldValidationFailure(
            field: 'attributes.${definition.key}',
            message: 'Falta el atributo obligatorio «${definition.label}»',
          );
        }
        continue;
      }
      final valid = switch (definition.type) {
        AttributeType.number => value is num && value >= 0,
        AttributeType.text => value is String && value.trim().isNotEmpty,
        AttributeType.boolean => value is bool,
        AttributeType.choice => definition.allowedValues.contains(value),
        AttributeType.choices =>
          value is List && value.isNotEmpty && value.every(definition.allowedValues.contains),
      };
      if (!valid) {
        throw FieldValidationFailure(
          field: 'attributes.${definition.key}',
          message: 'Valor inválido para «${definition.label}»',
        );
      }
    }
    if (product.images.isEmpty || product.images.length > 8) {
      throw const FieldValidationFailure(field: 'images', message: 'Agrega entre 1 y 8 imágenes');
    }
    if (product.images.any((path) => !path.startsWith('${store.id}/') || !uploadedImages.containsKey(path))) {
      throw const FieldValidationFailure(
        field: 'images',
        message: 'Alguna imagen no es de tu tienda o no se terminó de subir',
      );
    }
  }

  static void _validateOffer(OfferInput offer) {
    if (offer.priceCents <= 0 || offer.priceCents % 100 != 0) {
      throw const FieldValidationFailure(
        field: 'priceCents',
        message: 'El precio debe ser mayor que 0 y en pesos enteros',
      );
    }
    final old = offer.oldPriceCents;
    if (old != null && (old <= offer.priceCents || old % 100 != 0)) {
      throw const FieldValidationFailure(
        field: 'oldPriceCents',
        message: 'El precio anterior debe ser mayor que el precio actual',
      );
    }
    if (offer.stockUnits < 0 || offer.stockUnits > 100000) {
      throw const FieldValidationFailure(
        field: 'stockUnits',
        message: 'Las existencias deben ser un número entero de 0 a 100000',
      );
    }
    if (offer.status == OfferStatus.retired) {
      throw const FieldValidationFailure(
        field: 'status',
        message: 'El estado debe ser borrador, publicada o pausada',
      );
    }
  }

  static String _key(String value) => value.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

  void _checkDuplicates(ProductInput product, String? currentId, {required bool confirmDistinct}) {
    final brand = _key(product.brand);
    final model = _key(product.model);
    final candidates = [
      for (final sheet in _allSheets())
        if (sheet.id != currentId && sheet.category == product.category && _key(sheet.brand) == brand) sheet,
    ];
    for (final sheet in candidates) {
      if (_key(sheet.model) == model) {
        throw ProductExistsFailure(productId: sheet.id, productName: sheet.name);
      }
    }
    if (confirmDistinct || model.length < 4) return;
    final similar = [
      for (final sheet in candidates)
        if (_key(sheet.model).length >= 4 &&
            (_key(sheet.model).contains(model) || model.contains(_key(sheet.model))))
          DuplicateCandidate(productId: sheet.id, name: sheet.name, model: sheet.model),
    ];
    if (similar.isNotEmpty) throw PossibleDuplicateFailure(similar);
  }
}
