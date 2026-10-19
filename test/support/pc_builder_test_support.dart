import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:prueba01/features/catalog/data/mock_product_repository.dart';
import 'package:prueba01/features/catalog/domain/product.dart';
import 'package:prueba01/features/pc_builder/domain/pc_builder_models.dart';
import 'package:prueba01/features/pc_builder/domain/build_scene.dart';
import 'package:prueba01/features/pc_builder/domain/pc_builder_repository.dart';
import 'package:prueba01/features/pc_builder/presentation/viewer/viewer_host.dart';

/// Motor guionado para pruebas de pantalla: arma las piezas con el mock del
/// catálogo y aplica una sola regla conocida (Ryzen AM5 con la placa Z790
/// LGA1700 no encaja). Con [socketRule] en `false` ese par es compatible,
/// para probar una configuración completa (el mock solo tiene ese CPU y esa
/// placa).
class ScriptedBuilderRepository implements PcBuilderRepository {
  ScriptedBuilderRepository(this.products, {this.socketRule = true});

  final MockProductRepository products;
  final bool socketRule;
  final validateCalls = <List<String>>[];
  final sceneCalls = <List<String>>[];

  static const ryzen = 'mock-offer-ryzen-9-9950x';
  static const z790 = 'mock-offer-rog-maximus-z790-hero';
  static const rtx5080 = 'mock-offer-rtx-5080';

  /// Ranuras reducidas: CPU y placa obligatorias, gráfica opcional.
  static const slots = [
    BuilderSlot(category: ProductCategory.cpu, label: 'Procesador', required: true),
    BuilderSlot(category: ProductCategory.motherboard, label: 'Placa madre', required: true),
    BuilderSlot(category: ProductCategory.gpu, label: 'Tarjeta gráfica', required: false),
  ];

  static const socketMessage =
      'El procesador usa el socket AM5 y la placa madre el LGA1700: no encajan entre sí.';

  bool _conflicts(List<String> offerIds, String candidateOfferId) =>
      socketRule && offerIds.contains(ryzen) && candidateOfferId == z790;

  @override
  Future<List<BuilderSlot>> getSlots() async => slots;

  @override
  Future<BuildValidation> validate(List<String> offerIds) async {
    validateCalls.add(offerIds);
    final parts = [
      for (final offerId in offerIds)
        if (products.offerById(offerId) case final found?)
          BuildPart(
            offerId: offerId,
            category: found.product.category,
            productId: found.product.id,
            productName: found.product.name,
            brand: found.product.brand,
            providerName: found.offer.providerName,
            priceCents: found.offer.priceCents,
            isAvailable: found.stockUnits > 0,
          ),
    ];
    final issues = [
      if (offerIds.contains(z790) && _conflicts(offerIds, z790))
        const BuildIssue(
          ruleCode: 'cpu_motherboard_socket',
          severity: IssueSeverity.error,
          message: socketMessage,
          offerIds: [ryzen, z790],
        ),
    ];
    final missing = [
      for (final slot in slots)
        if (slot.required && !parts.any((p) => p.category == slot.category)) slot,
    ];
    final valid = issues.isEmpty && missing.isEmpty;
    return BuildValidation(
      valid: valid,
      purchasable: valid && parts.every((p) => p.isAvailable),
      parts: parts,
      issues: issues,
      missingSlots: missing,
      totalCents: parts.fold(0, (sum, p) => sum + p.priceCents),
    );
  }

  @override
  Future<List<BuilderCandidate>> candidates(
    ProductCategory category,
    List<String> offerIds,
  ) async => [
    for (final product in products.productsIn(category))
      BuilderCandidate(
        product: product,
        compatible: !_conflicts(offerIds, product.bestOfferId ?? ''),
        incompatibilityReason: _conflicts(offerIds, product.bestOfferId ?? '')
            ? socketMessage
            : null,
      ),
  ];

  /// Modelo genérico de gráfica, como el del seed (CC BY).
  static const gpuModel = PartModel(
    url: 'https://modelos.test/generic/gpu.glb',
    rotation: [0, 180, 0],
    generic: true,
    credit: ModelCredit(
      title: 'Graphics card',
      author: 'pgonarg',
      license: 'CC-BY-3.0',
      sourceUrl: 'https://poly.pizza/m/i45v5trpyR',
    ),
  );

  @override
  Future<BuildScene> scene(List<String> offerIds) async {
    sceneCalls.add(offerIds);
    return BuildScene(
      parts: [
        for (final offerId in offerIds)
          if (products.offerById(offerId) case final found?)
            ScenePart(
              offerId: offerId,
              category: found.product.category,
              productName: found.product.name,
              model: found.product.category == ProductCategory.gpu ? gpuModel : null,
              attributes: found.product.category == ProductCategory.gpu
                  ? const {'length_mm': 304}
                  : const {},
            ),
      ],
    );
  }

  /// Armado con componentes; el de oficina no tiene componentes registrados.
  static const gamerPro = 'pc-gamer-pro-r7-5070';
  static const office = 'pc-oficina-i5-14400';

  @override
  Future<PrebuiltScene> prebuiltScene(String productId) async {
    final product = products
        .productsIn(ProductCategory.prebuiltPc)
        .firstWhere((p) => p.id == productId);
    return PrebuiltScene(
      product: product,
      scene: BuildScene(
        parts: productId != gamerPro
            ? const []
            : const [
                ScenePart(
                  offerId: '$gamerPro:cpu',
                  category: ProductCategory.cpu,
                  productName: 'AMD Ryzen 7 9700X',
                ),
                ScenePart(
                  offerId: '$gamerPro:ram',
                  category: ProductCategory.ram,
                  productName: 'DDR5 32 GB (2 x 16 GB)',
                  attributes: {'modules': 2},
                ),
                ScenePart(
                  offerId: '$gamerPro:gpu',
                  category: ProductCategory.gpu,
                  productName: 'NVIDIA GeForce RTX 5070 12 GB',
                  model: gpuModel,
                  attributes: {'length_mm': 242},
                ),
              ],
      ),
    );
  }
}

/// Visor falso: guarda las escenas que recibiría y permite simular sus
/// eventos (toques, carga, fallas).
class FakeViewer {
  final messages = <String>[];
  ValueChanged<ViewerEvent>? _onEvent;

  Widget build(String sceneMessage, ValueChanged<ViewerEvent> onEvent) {
    if (messages.isEmpty || messages.last != sceneMessage) {
      messages.add(sceneMessage);
    }
    _onEvent = onEvent;
    return const SizedBox.expand(key: Key('fake-viewer'));
  }

  void emit(ViewerEvent event) => _onEvent!(event);

  /// Nodos de la última escena enviada.
  List<Map<String, Object?>> get nodes => [
    for (final node in (jsonDecode(messages.last) as Map)['nodes'] as List)
      (node as Map).cast<String, Object?>(),
  ];

  Map<String, Object?>? node(String id) {
    for (final node in nodes) {
      if (node['id'] == id) return node;
    }
    return null;
  }
}
