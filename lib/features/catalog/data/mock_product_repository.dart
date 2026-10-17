import '../domain/product.dart';
import '../domain/product_page.dart';
import '../domain/product_repository.dart';

class MockProductRepository implements ProductRepository {
  MockProductRepository({this.latency = const Duration(milliseconds: 300)}) {
    _products = _seedProducts();
  }

  MockProductRepository.generated(
    int count, {
    this.latency = const Duration(milliseconds: 300),
  }) : _products = _generateProducts(count);

  final Duration latency;
  late final List<Product> _products;

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

  @override
  Future<ProductPage> getProducts({
    int page = 0,
    int pageSize = 20,
    String? search,
    ProductCategory? category,
  }) async {
    if (page < 0) {
      throw ArgumentError.value(page, 'page', 'Must not be negative');
    }
    if (pageSize <= 0) {
      throw ArgumentError.value(pageSize, 'pageSize', 'Must be greater than 0');
    }

    await Future<void>.delayed(latency);
    final normalizedSearch = search == null ? null : _normalizeSearch(search);
    final matchingProducts = _products
        .where((product) {
          if (category != null && product.category != category) return false;
          if (normalizedSearch == null || normalizedSearch.isEmpty) return true;

          return _normalizeSearch(product.name).contains(normalizedSearch) ||
              _normalizeSearch(product.brand).contains(normalizedSearch) ||
              _categorySearchTerms(product.category).any(
                (term) => _normalizeSearch(term).contains(normalizedSearch),
              );
        })
        .toList(growable: false);

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
    for (final product in _products) {
      if (product.id == id) return product;
    }
    return null;
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

  Product? _findById(String id) {
    for (final product in _products) {
      if (product.id == id) return product;
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
