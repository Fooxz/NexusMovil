import '../domain/catalog_offer.dart';
import '../domain/product.dart';
import '../domain/product_filters.dart';
import '../domain/product_page.dart';
import '../domain/product_repository.dart';

/// Repositorio en memoria para desarrollar sin backend. Se comporta como el
/// contrato: el listado no trae ofertas y el detalle sí.
class MockProductRepository implements ProductRepository {
  MockProductRepository({this.latency = const Duration(milliseconds: 300)}) {
    _products = [for (final product in _seedProducts()) _withBestOffer(product)];
  }

  MockProductRepository.generated(
    int count, {
    this.latency = const Duration(milliseconds: 300),
  }) : _products = [
         for (final product in _generateProducts(count)) _withBestOffer(product),
       ];

  final Duration latency;
  late final List<Product> _products;

  static const _offersByProductId = {
    'rtx-5090': [
      ProductOffer(
        id: 'off-tp-rtx5090',
        providerId: 'prov-tecnopartes',
        providerName: 'TecnoPartes',
        priceCents: 799600000,
        oldPriceCents: 919600000,
        stockLevel: StockLevel.stable,
      ),
      ProductOffer(
        id: 'off-mp-rtx5090',
        providerId: 'prov-mundopc',
        providerName: 'Mundo PC',
        priceCents: 815000000,
        stockLevel: StockLevel.critical,
      ),
    ],
  };

  static List<Product> _seedProducts() => [
    const Product(
      id: 'rtx-5090',
      name: 'NVIDIA GEFORCE RTX 5090',
      brand: 'NVIDIA',
      category: ProductCategory.gpu,
      priceCents: 799600000,
      oldPriceCents: 919600000,
      stockLevel: StockLevel.stable,
      summary: '24 GB GDDR6X · 2.5K · Ray tracing',
      quickSpecs: [
        'ADALACE',
        '16384 CORES',
        '24GB GDDR6X',
        '450W',
        'PCI-E 5.0',
        'ATX',
      ],
      specs: [
        ProductSpec(label: 'ARQUITECTURA', value: 'ADALACE'),
        ProductSpec(label: 'CORES', value: '16384'),
        ProductSpec(label: 'VRAM', value: '24GB GDDR6X'),
        ProductSpec(label: 'TDP', value: '450W'),
        ProductSpec(label: 'INTERFAZ', value: 'PCI-E 5.0 x16'),
      ],
    ),
    const Product(
      id: 'ryzen-9-9950x',
      name: 'RYZEN 9 9950X',
      brand: 'AMD',
      category: ProductCategory.cpu,
      priceCents: 259600000,
      oldPriceCents: 279600000,
      stockLevel: StockLevel.stable,
      summary: '16 núcleos · 5.7 GHz · Zen 5',
    ),
    const Product(
      id: 'rog-maximus-z790-hero',
      name: 'ROG MAXIMUS Z790 HERO',
      brand: 'ASUS',
      category: ProductCategory.motherboard,
      priceCents: 599990000,
      oldPriceCents: 699990000,
      stockLevel: StockLevel.critical,
      summary: 'Z890 · Wi-Fi 7 · 24+2 fases',
    ),
    const Product(
      id: 'kraken-elite-360',
      name: 'KRAKEN ELITE 360',
      brand: 'NZXT',
      category: ProductCategory.cooling,
      priceCents: 299990000,
      oldPriceCents: 329990000,
      stockLevel: StockLevel.outOfStock,
      summary: '360 mm · RGB · 2x fans',
    ),
    const Product(
      id: 'rtx-5080',
      name: 'NVIDIA RTX 5080',
      brand: 'NVIDIA',
      category: ProductCategory.gpu,
      priceCents: 169900000,
      stockLevel: StockLevel.stable,
      quickSpecs: ['RTX 5080', '16GB'],
    ),
    const Product(
      id: 'cooler-master-elite-liquid-360',
      name: 'Cooler Master Elite Liquid 360',
      brand: 'Cooler Master',
      category: ProductCategory.cooling,
      priceCents: 249000000,
      stockLevel: StockLevel.stable,
      quickSpecs: ['LIQUID', '360MM'],
    ),
  ];

  static List<Product> _generateProducts(int count) {
    final generated = <Product>[];
    for (var index = 0; index < count; index++) {
      final category = ProductCategory.values[index % ProductCategory.values.length];
      final stockLevel = switch (index % 3) {
        0 => StockLevel.stable,
        1 => StockLevel.critical,
        _ => StockLevel.outOfStock,
      };
      final basePrice = 4000000 + (index * 450000);
      final oldPrice = basePrice + 600000;
      generated.add(
        Product(
          id: 'generated-${index + 1}',
          name: '${category.name.toUpperCase()} PRODUCT ${index + 1}',
          brand: switch (index % 5) {
            0 => 'NVIDIA',
            1 => 'AMD',
            2 => 'ASUS',
            3 => 'NZXT',
            _ => 'CORSAIR',
          },
          category: category,
          priceCents: basePrice,
          oldPriceCents: oldPrice,
          stockLevel: stockLevel,
          summary: 'Producto sintético ${index + 1}',
        ),
      );
    }
    return generated;
  }

  /// Como `get_offers`: una tarjeta por oferta, filtrada por tienda y por el
  /// precio de cada oferta. La búsqueda también encuentra por tienda.
  @override
  Future<OfferPage> getOffers({
    int page = 0,
    int pageSize = 20,
    ProductFilters filters = const ProductFilters(),
  }) async {
    if (page < 0) {
      throw ArgumentError.value(page, 'page', 'Must not be negative');
    }
    if (pageSize <= 0) {
      throw ArgumentError.value(pageSize, 'pageSize', 'Must be greater than 0');
    }

    await Future<void>.delayed(latency);
    final offers = _filterOffers(filters);
    return OfferPage(
      items: offers.skip(page * pageSize).take(pageSize).toList(),
      total: offers.length,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<List<CatalogStore>> getStores({ProductCategory? category}) async {
    await Future<void>.delayed(latency);
    final counts = <String, ({String name, int count})>{};
    for (final offer in _filterOffers(ProductFilters(category: category))) {
      final current = counts[offer.providerId];
      counts[offer.providerId] = (
        name: offer.providerName,
        count: (current?.count ?? 0) + 1,
      );
    }
    return [
      for (final entry in counts.entries)
        CatalogStore(id: entry.key, displayName: entry.value.name, offerCount: entry.value.count),
    ]..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
  }

  List<CatalogOffer> _filterOffers(ProductFilters filters) {
    final search = _normalizeSearch(filters.search);
    final products = _filter(
      ProductFilters(category: filters.category, brand: filters.brand),
    );
    final offers = <CatalogOffer>[];
    for (final product in products) {
      final productOffers = _offersOf(product);
      // Como el backend: dentro de un producto, primero con stock y por precio.
      final ordered = [...productOffers]..sort((a, b) {
          final byStock = (a.stockLevel == StockLevel.outOfStock ? 1 : 0)
              .compareTo(b.stockLevel == StockLevel.outOfStock ? 1 : 0);
          return byStock != 0 ? byStock : a.priceCents.compareTo(b.priceCents);
        });
      for (final offer in ordered) {
        if (filters.providerId != null && offer.providerId != filters.providerId) continue;
        if (filters.minPriceCents != null && offer.priceCents < filters.minPriceCents!) continue;
        if (filters.maxPriceCents != null && offer.priceCents > filters.maxPriceCents!) continue;
        if (search.isNotEmpty &&
            !_matchesSearch(product, search) &&
            !_normalizeSearch(offer.providerName).contains(search)) {
          continue;
        }
        offers.add(
          CatalogOffer(
            offerId: offer.id,
            productId: product.id,
            name: product.name,
            brand: product.brand,
            category: product.category,
            providerId: offer.providerId,
            providerName: offer.providerName,
            priceCents: offer.priceCents,
            oldPriceCents: offer.oldPriceCents,
            stockLevel: offer.stockLevel,
            imageUrl: product.imageUrl,
            summary: product.summary,
            quickSpecs: product.quickSpecs,
            offerCount: productOffers.length,
          ),
        );
      }
    }

    if (filters.sort != ProductSort.relevance) {
      final positions = {for (var i = 0; i < offers.length; i++) offers[i].offerId: i};
      final ascending = filters.sort == ProductSort.priceAsc;
      offers.sort((a, b) {
        final byPrice = ascending
            ? a.priceCents.compareTo(b.priceCents)
            : b.priceCents.compareTo(a.priceCents);
        return byPrice != 0 ? byPrice : positions[a.offerId]!.compareTo(positions[b.offerId]!);
      });
    }
    return offers;
  }

  @override
  Future<ProductPage> getProducts({
    int page = 0,
    int pageSize = 20,
    ProductFilters filters = const ProductFilters(),
  }) async {
    if (page < 0) {
      throw ArgumentError.value(page, 'page', 'Must not be negative');
    }
    if (pageSize <= 0) {
      throw ArgumentError.value(pageSize, 'pageSize', 'Must be greater than 0');
    }

    await Future<void>.delayed(latency);
    final matchingProducts = _filter(filters);
    final start = page * pageSize;
    final items = matchingProducts.skip(start).take(pageSize).toList();
    return ProductPage(
      items: items,
      total: matchingProducts.length,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<Product?> getById(String id) async {
    await Future<void>.delayed(latency);
    final product = _findById(id);
    if (product == null) return null;
    return product.copyWith(offers: _offersByProductId[id] ?? const []);
  }

  @override
  Future<List<Product>> getRelated(String id, {int limit = 2}) async {
    await Future<void>.delayed(latency);
    if (limit <= 0) return const [];

    final product = _findById(id);
    if (product == null) return const [];

    final sameCategory = _products.where(
      (candidate) =>
          candidate.id != id && candidate.category == product.category,
    );
    final otherCategories = _products.where(
      (candidate) =>
          candidate.id != id && candidate.category != product.category,
    );
    return [...sameCategory, ...otherCategories].take(limit).toList();
  }

  @override
  Future<List<String>> getBrands({ProductCategory? category}) async {
    await Future<void>.delayed(latency);
    final brands = _filter(ProductFilters(category: category)).map((product) => product.brand).toSet().toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return brands;
  }

  List<Product> _filter(ProductFilters filters) {
    final normalizedSearch = _normalizeSearch(filters.search);
    final brand = filters.brand?.toLowerCase();
    final matches = _products.where((product) {
      if (filters.category != null && product.category != filters.category) {
        return false;
      }
      if (brand != null && product.brand.toLowerCase() != brand) return false;
      if (filters.minPriceCents != null &&
          product.priceCents < filters.minPriceCents!) {
        return false;
      }
      if (filters.maxPriceCents != null &&
          product.priceCents > filters.maxPriceCents!) {
        return false;
      }
      if (normalizedSearch.isEmpty) return true;
      return _matchesSearch(product, normalizedSearch);
    }).toList();

    // En `relevance` el mock conserva el orden de inserción (el backend ordena
    // por nombre). Por precio, el orden de inserción desempata.
    switch (filters.sort) {
      case ProductSort.relevance:
        break;
      case ProductSort.priceAsc:
        _stableSortByPrice(matches, ascending: true);
      case ProductSort.priceDesc:
        _stableSortByPrice(matches, ascending: false);
    }
    return matches;
  }

  static bool _matchesSearch(Product product, String normalizedSearch) =>
      _normalizeSearch(product.name).contains(normalizedSearch) ||
      _normalizeSearch(product.brand).contains(normalizedSearch) ||
      _categorySearchTerms(product.category).any(
        (term) => _normalizeSearch(term).contains(normalizedSearch),
      );

  void _stableSortByPrice(List<Product> products, {required bool ascending}) {
    final positions = {
      for (var index = 0; index < products.length; index++)
        products[index].id: index,
    };
    products.sort((a, b) {
      final byPrice = ascending
          ? a.priceCents.compareTo(b.priceCents)
          : b.priceCents.compareTo(a.priceCents);
      return byPrice != 0 ? byPrice : positions[a.id]!.compareTo(positions[b.id]!);
    });
  }

  Product? _findById(String id) {
    for (final product in _products) {
      if (product.id == id) return product;
    }
    return null;
  }

  static Product _withBestOffer(Product product) => product.copyWith(
    bestOfferId:
        _offersByProductId[product.id]?.first.id ?? _syntheticOfferId(product.id),
  );

  static String _syntheticOfferId(String productId) => 'mock-offer-$productId';

  /// Ofertas de un producto: las explícitas o una sintética de "Tienda demo".
  static List<ProductOffer> _offersOf(Product product) =>
      _offersByProductId[product.id] ??
      [
        ProductOffer(
          id: _syntheticOfferId(product.id),
          providerId: 'prov-demo',
          providerName: 'Tienda demo',
          priceCents: product.priceCents,
          oldPriceCents: product.oldPriceCents,
          stockLevel: product.stockLevel,
        ),
      ];

  /// Stock simulado según el nivel: el mock no maneja unidades reales.
  static int _unitsFor(StockLevel level) => switch (level) {
    StockLevel.stable => 20,
    StockLevel.critical => 3,
    StockLevel.outOfStock => 0,
  };

  /// Productos de una categoría, sin latencia (para el armador del mock).
  List<Product> productsIn(ProductCategory category) => [
    for (final product in _products)
      if (product.category == category) product,
  ];

  /// Oferta con su producto y su stock simulado, para el carrito del mock.
  /// Los productos sin ofertas explícitas tienen una sintética de "Tienda demo".
  ({Product product, ProductOffer offer, int stockUnits})? offerById(
    String offerId,
  ) {
    for (final product in _products) {
      for (final offer in _offersOf(product)) {
        if (offer.id == offerId) {
          return (
            product: product,
            offer: offer,
            stockUnits: _unitsFor(offer.stockLevel),
          );
        }
      }
    }
    return null;
  }

  static String _normalizeSearch(String value) =>
      value.trim().toLowerCase().replaceAllMapped(
        RegExp('[áéíóúüñ]'),
        (match) => switch (match[0]) {
          'á' => 'a',
          'é' => 'e',
          'í' => 'i',
          'ó' => 'o',
          'ú' => 'u',
          'ü' => 'u',
          'ñ' => 'n',
          _ => match[0]!,
        },
      );

  static List<String> _categorySearchTerms(ProductCategory category) =>
      switch (category) {
        ProductCategory.cpu => const ['cpu', 'procesador'],
        ProductCategory.gpu => const ['gpu', 'tarjeta grafica', 'tarjetas graficas'],
        ProductCategory.ram => const ['ram', 'memoria'],
        ProductCategory.motherboard => const ['motherboard', 'placa madre'],
        ProductCategory.storage => const ['storage', 'almacenamiento'],
        ProductCategory.psu => const ['psu', 'fuente'],
        ProductCategory.pcCase => const ['pccase', 'gabinete', 'case'],
        ProductCategory.cooling => const ['cooling', 'refrigeracion'],
      };
}
