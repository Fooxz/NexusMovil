import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/features/catalog/domain/product.dart';
import 'package:prueba01/features/pc_builder/domain/build_scene.dart';
import 'package:prueba01/features/pc_builder/presentation/viewer/scene_layout.dart';

const _credit = ModelCredit(title: 'M', author: 'A', license: 'CC0-1.0');

PartModel _model(String file, {bool generic = true}) =>
    PartModel(url: 'https://m.test/$file', credit: _credit, generic: generic);

ScenePart _part(
  ProductCategory category, {
  String? offerId,
  Map<String, Object?> attributes = const {},
  PartModel? model,
}) => ScenePart(
  offerId: offerId ?? 'off-${category.name}',
  category: category,
  productName: category.name,
  attributes: attributes,
  model: model,
);

ViewerScene _layout(List<ScenePart> parts, {Set<String> errors = const {}}) =>
    layoutScene(BuildScene(parts: parts), errorOfferIds: errors);

void main() {
  test('without a case, a reference case is drawn as a ghost', () {
    final scene = _layout([_part(ProductCategory.cpu)]);

    final pcCase = scene.node('case')!;
    expect(pcCase.state, NodeState.ghost);
    expect(pcCase.part, isEmpty);
    expect(scene.caseSize, [450, caseHeightMm, 220]);
  });

  test('the case grows with the GPU and cooler it admits', () {
    final scene = _layout([
      _part(
        ProductCategory.pcCase,
        attributes: {'max_gpu_length_mm': 426, 'max_cooler_height_mm': 167},
      ),
    ]);

    expect(scene.caseSize, [466, caseHeightMm, 222]);
    expect(scene.node('case')!.state, NodeState.normal);
  });

  test('the motherboard size follows its form factor', () {
    List<double> boardSize(String? formFactor) => _layout([
      _part(
        ProductCategory.motherboard,
        attributes: {'form_factor': ?formFactor},
      ),
    ]).node('off-motherboard')!.size;

    expect(boardSize('ATX').take(2), [244, 305]);
    expect(boardSize('microATX').take(2), [244, 244]);
    expect(boardSize('miniITX').take(2), [170, 170]);
    expect(boardSize('EATX').take(2), [330, 305]);
    expect(boardSize(null).take(2), [244, 305], reason: 'ATX sin el dato');
  });

  test('the GPU is as long as the real card, with its bracket at the rear', () {
    final scene = _layout([
      _part(ProductCategory.gpu, attributes: {'length_mm': 336}),
    ]);

    final gpu = scene.node('off-gpu')!;
    expect(gpu.size.first, 336);
    expect(gpu.align.first, 'max');
    final rearEdge = gpu.center.first + gpu.size.first / 2;
    expect(rearEdge, closeTo(scene.caseSize.first / 2 - 8, 0.001),
        reason: 'el soporte llega a la trasera del gabinete');
    expect(_layout([_part(ProductCategory.gpu)]).node('off-gpu')!.size.first,
        defaultGpuLengthMm);
  });

  test('RAM sticks go in A2 and B2 first, as many as the kit has', () {
    List<double> sticksX(int modules, {int? slots}) {
      final scene = _layout([
        _part(ProductCategory.motherboard, attributes: {'ram_slots': ?slots}),
        _part(ProductCategory.ram, attributes: {'modules': modules}),
      ]);
      return [
        for (final node in scene.nodes)
          if (node.kind == 'ram') node.center.first,
      ];
    }

    final four = sticksX(4);
    expect(four, hasLength(4));
    expect(sticksX(2), [four[1], four[3]]);
    expect(sticksX(1), [four[1]]);
    expect(sticksX(4, slots: 2), hasLength(2), reason: 'no más que las ranuras');
  });

  test('air coolers use their height and liquid ones a pump and radiator', () {
    final air = _layout([
      _part(ProductCategory.cooling, attributes: {'cooling_type': 'air', 'height_mm': 158}),
    ]);
    expect(air.node('off-cooling')!.kind, 'airCooler');
    expect(air.node('off-cooling')!.size.last, 158);

    final liquid = _layout([
      _part(ProductCategory.cooling, attributes: {'cooling_type': 'liquid', 'radiator_mm': 360}),
    ]);
    expect(liquid.node('off-cooling#pump')!.kind, 'pump');
    expect(liquid.node('off-cooling#radiator')!.size.first, 360);
    expect(
      {for (final node in liquid.nodes) if (node.kind != 'case') node.part},
      {'off-cooling'},
      reason: 'las dos piezas son la misma oferta',
    );
  });

  test('storage is drawn by its type', () {
    String kind(String type) => _layout([
      _part(ProductCategory.storage, attributes: {'storage_type': type}),
    ]).node('off-storage')!.kind;

    expect(kind('NVMe'), 'm2');
    expect(kind('SATA_SSD'), 'ssd25');
    expect(kind('HDD'), 'hdd35');
  });

  test('every node of a part with an incompatibility is marked', () {
    final scene = _layout([
      _part(ProductCategory.ram, attributes: {'modules': 2}),
      _part(ProductCategory.cpu),
    ], errors: {'off-ram'});

    expect(
      [for (final node in scene.nodes) if (node.part == 'off-ram') node.state],
      [NodeState.error, NodeState.error],
    );
    expect(scene.node('off-cpu')!.state, NodeState.normal);
  });

  test('generic models are used only where their shape fits', () {
    final scene = _layout([
      _part(ProductCategory.gpu, model: _model('gpu.glb')),
      _part(ProductCategory.storage, model: _model('ssd.glb')),
      _part(ProductCategory.cooling, model: _model('cooler.glb')),
      _part(ProductCategory.pcCase, model: _model('case.glb')),
    ]);

    expect(scene.node('off-gpu')!.model, isNotNull);
    expect(scene.node('off-storage')!.model, isNull, reason: 'el tipo cambia la forma');
    expect(scene.node('off-cooling')!.model, isNull, reason: 'puede ser líquida');
    expect(scene.node('case')!.model, isNull, reason: 'taparía el interior');
    expect(scene.credits, [_credit], reason: 'solo los modelos usados');

    final own = _layout([
      _part(ProductCategory.pcCase, model: _model('o11.glb', generic: false)),
    ]);
    expect(own.node('case')!.model, isNotNull, reason: 'el del producto sí');
  });

  test('the message carries what the viewer needs', () {
    final message = jsonDecode(
      _layout([
        _part(ProductCategory.gpu, model: _model('gpu.glb')),
      ]).toMessage(),
    ) as Map<String, Object?>;

    expect(message['type'], 'scene');
    expect((message['case'] as Map)['size'], [450, caseHeightMm, 220]);
    final gpu = (message['nodes'] as List).cast<Map<String, Object?>>().last;
    expect(gpu, containsPair('url', 'https://m.test/gpu.glb'));
    expect(gpu, containsPair('modelRotation', [0, 0, 0]));
    expect(gpu, containsPair('rotation', [90, 0, 0]));
    expect(gpu, containsPair('state', 'normal'));
  });
}
