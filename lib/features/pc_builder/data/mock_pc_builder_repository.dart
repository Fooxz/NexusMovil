import '../../../core/errors/app_failure.dart';
import '../../catalog/data/mock_product_repository.dart';
import '../../catalog/domain/product.dart';
import '../domain/build_scene.dart';
import '../domain/pc_builder_models.dart';
import '../domain/pc_builder_repository.dart';

/// Armador sin backend. El mock del catálogo no tiene atributos técnicos, así
/// que **no verifica compatibilidad**: lo dice con un aviso en vez de afirmar
/// que las piezas son compatibles (RN-013, RN-014). Sí aplica las ranuras
/// obligatorias y la disponibilidad.
class MockPcBuilderRepository implements PcBuilderRepository {
  MockPcBuilderRepository(this._products);

  final MockProductRepository _products;

  static const noRulesMessage =
      'Modo sin backend: la compatibilidad entre piezas no se está verificando.';

  static const slots = [
    BuilderSlot(category: ProductCategory.cpu, label: 'Procesador', required: true),
    BuilderSlot(category: ProductCategory.motherboard, label: 'Placa madre', required: true),
    BuilderSlot(category: ProductCategory.ram, label: 'Memoria RAM', required: true),
    BuilderSlot(category: ProductCategory.gpu, label: 'Tarjeta gráfica', required: false),
    BuilderSlot(category: ProductCategory.storage, label: 'Almacenamiento', required: true),
    BuilderSlot(category: ProductCategory.psu, label: 'Fuente de poder', required: true),
    BuilderSlot(category: ProductCategory.pcCase, label: 'Gabinete', required: true),
    BuilderSlot(category: ProductCategory.cooling, label: 'Refrigeración', required: false),
  ];

  @override
  Future<List<BuilderSlot>> getSlots() async => slots;

  @override
  Future<BuildValidation> validate(List<String> offerIds) async {
    final parts = <BuildPart>[];
    for (final offerId in offerIds) {
      final found = _products.offerById(offerId);
      if (found == null) throw const NotFoundFailure();
      if (found.product.family != ProductFamily.part) {
        throw const ValidationFailure();
      }
      if (parts.any((part) => part.category == found.product.category)) {
        throw const ValidationFailure();
      }
      parts.add(
        BuildPart(
          offerId: offerId,
          category: found.product.category,
          productId: found.product.id,
          productName: found.product.name,
          brand: found.product.brand,
          providerName: found.offer.providerName,
          priceCents: found.offer.priceCents,
          isAvailable: found.stockUnits > 0,
          imageUrl: found.product.imageUrl,
        ),
      );
    }

    final missing = [
      for (final slot in slots)
        if (slot.required && !parts.any((part) => part.category == slot.category))
          slot,
    ];
    final valid = missing.isEmpty;
    return BuildValidation(
      valid: valid,
      purchasable: valid && parts.every((part) => part.isAvailable),
      parts: parts,
      issues: [
        if (parts.isNotEmpty)
          BuildIssue(
            ruleCode: 'mock_no_rules',
            severity: IssueSeverity.warning,
            message: noRulesMessage,
            offerIds: const [],
          ),
      ],
      missingSlots: missing,
      totalCents: parts.fold(0, (sum, part) => sum + part.priceCents),
    );
  }

  @override
  Future<List<BuilderCandidate>> candidates(
    ProductCategory category,
    List<String> offerIds,
  ) async {
    final products = _products.productsIn(category)
      ..sort((a, b) {
        final byStock = (a.stockLevel == StockLevel.outOfStock ? 1 : 0) -
            (b.stockLevel == StockLevel.outOfStock ? 1 : 0);
        return byStock != 0 ? byStock : a.priceCents.compareTo(b.priceCents);
      });
    return [
      for (final product in products)
        BuilderCandidate(product: product, compatible: true),
    ];
  }

  /// Sin backend no hay modelos 3D ni atributos técnicos: el visor genera
  /// cada pieza con sus medidas típicas.
  @override
  Future<BuildScene> scene(List<String> offerIds) async {
    final validation = await validate(offerIds);
    return BuildScene(
      parts: [
        for (final part in validation.parts)
          ScenePart(
            offerId: part.offerId,
            category: part.category,
            productName: part.productName,
          ),
      ],
    );
  }

  /// El mock del catálogo no tiene componentes de armados: la pantalla lo
  /// explica.
  @override
  Future<PrebuiltScene> prebuiltScene(String productId) async {
    final product = await _products.getById(productId);
    if (product == null) throw const NotFoundFailure();
    if (product.category != ProductCategory.prebuiltPc) throw const ValidationFailure();
    return PrebuiltScene(product: product, scene: BuildScene.empty);
  }
}
