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
    const Product(
      id: 'pc-gamer-pro-r7-5070',
      name: 'PC GAMER PRO RYZEN 7 9700X / RTX 5070',
      brand: 'TecnoPartes',
      category: ProductCategory.prebuiltPc,
      priceCents: 749990000,
      stockLevel: StockLevel.critical,
      summary: 'Ryzen 7 9700X · 32 GB DDR5 · RTX 5070 · 1 TB NVMe',
      quickSpecs: ['GAMING', '32GB', 'RTX 5070'],
    ),
    const Product(
      id: 'pc-oficina-i5-14400',
      name: 'PC OFICINA CORE I5-14400',
      brand: 'Mundo PC',
      category: ProductCategory.prebuiltPc,
      priceCents: 229990000,
      stockLevel: StockLevel.stable,
      summary: 'Core i5-14400 · 16 GB · 512 GB NVMe',
      quickSpecs: ['OFICINA', '16GB'],
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
  Future<List<String>> getBrands({
    ProductFamily? family,
    ProductCategory? category,
  }) async {
    await Future<void>.delayed(latency);
    final brands = _filter(
      ProductFilters(family: family, category: category),
    ).map((product) => product.brand).toSet().toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return brands;
  }

  List<Product> _filter(ProductFilters filters) {
    final normalizedSearch = _normalizeSearch(filters.search);
    final brand = filters.brand?.toLowerCase();
    final matches = _products.where((product) {
      if (filters.family != null && product.family != filters.family) {
        return false;
      }
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

      return _normalizeSearch(product.name).contains(normalizedSearch) ||
          _normalizeSearch(product.brand).contains(normalizedSearch) ||
          _categorySearchTerms(product.category).any(
            (term) => _normalizeSearch(term).contains(normalizedSearch),
          );
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
      final offers = _offersByProductId[product.id] ??
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
      for (final offer in offers) {
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
        ProductCategory.prebuiltPc => const [
          'pc',
          'computador',
          'equipo',
          'armado',
        ],
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
