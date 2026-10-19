import 'dart:convert';
import 'dart:math' as math;

import '../../../catalog/domain/product.dart';
import '../../domain/build_scene.dart';

/// Ubica cada pieza de la configuración dentro del gabinete para el visor 3D
/// (tool/viewer). Es Dart puro: se prueba sin render.
///
/// Unidades en milímetros. Ejes del mundo: X es el fondo del gabinete (frente
/// en -X, trasera en +X), Y el alto y Z el ancho (placa al fondo en -Z, vidrio
/// en +Z). Cada nodo es una caja: el visor escala el modelo sin deformarlo
/// hasta que quepa y lo alinea según [ViewerNode.align]; sin modelo, genera la
/// pieza del tipo [ViewerNode.kind] con esas medidas.

enum NodeState { normal, error, ghost }

class ViewerNode {
  const ViewerNode({
    required this.id,
    required this.part,
    required this.kind,
    required this.center,
    required this.size,
    this.model,
    this.rotation = const [0, 0, 0],
    this.align = const ['center', 'center', 'center'],
    this.state = NodeState.normal,
    this.params = const {},
  });

  final String id;

  /// Oferta a la que pertenece (vacío para el gabinete de referencia).
  final String part;
  final String kind;
  final List<double> center;
  final List<double> size;
  final PartModel? model;

  /// Grados que llevan la orientación de la categoría a la del mundo.
  final List<double> rotation;
  final List<String> align;
  final NodeState state;
  final Map<String, Object?> params;

  Map<String, Object?> toJson() => {
    'id': id,
    'part': part,
    'kind': kind,
    if (model case final model?) ...{
      'url': model.url,
      'modelRotation': model.rotation,
    },
    'rotation': rotation,
    'center': center,
    'size': size,
    'align': align,
    'state': state.name,
    if (params.isNotEmpty) 'params': params,
  };
}

class ViewerScene {
  const ViewerScene({
    required this.caseSize,
    required this.nodes,
    required this.credits,
  });

  final List<double> caseSize;
  final List<ViewerNode> nodes;

  /// Créditos de los modelos que se usan en esta escena.
  final List<ModelCredit> credits;

  ViewerNode? node(String id) {
    for (final node in nodes) {
      if (node.id == id) return node;
    }
    return null;
  }

  /// Mensaje `scene` para el visor.
  String toMessage() => jsonEncode({
    'type': 'scene',
    'case': {'size': caseSize},
    'nodes': [for (final node in nodes) node.toJson()],
  });
}

/// Medidas de cada formato de placa y dónde quedan el socket, las ranuras de
/// memoria, las PCIe y la M.2. Las posiciones (u, v) se miden desde la
/// esquina superior trasera: u hacia el frente, v hacia abajo.
class _BoardLayout {
  const _BoardLayout({
    required this.width,
    required this.height,
    required this.socket,
    required this.dimms,
    required this.dimmV,
    required this.pcie,
    required this.m2,
  });

  final double width;
  final double height;
  final (double, double) socket;
  final List<double> dimms;
  final double dimmV;
  final List<double> pcie;
  final (double, double) m2;
}

const _atx = _BoardLayout(
  width: 244,
  height: 305,
  socket: (100, 92),
  dimms: [158, 168, 178, 188],
  dimmV: 100,
  pcie: [170, 250],
  m2: (122, 142),
);

const _boards = {
  'ATX': _atx,
  'EATX': _BoardLayout(
    width: 330,
    height: 305,
    socket: (110, 92),
    dimms: [170, 180, 190, 200],
    dimmV: 100,
    pcie: [170, 250],
    m2: (130, 142),
  ),
  'microATX': _BoardLayout(
    width: 244,
    height: 244,
    socket: (100, 85),
    dimms: [158, 168, 178, 188],
    dimmV: 95,
    pcie: [160, 215],
    m2: (122, 132),
  ),
  'miniITX': _BoardLayout(
    width: 170,
    height: 170,
    socket: (78, 70),
    dimms: [138, 150],
    dimmV: 80,
    pcie: [150],
    m2: (85, 120),
  ),
};

/// Medidas típicas cuando la pieza no trae el atributo.
const defaultGpuLengthMm = 285.0;
const defaultCoolerHeightMm = 155.0;
const defaultRadiatorMm = 240.0;
const caseHeightMm = 470.0;

/// Orden en que se llenan las ranuras de memoria (A2 y B2 primero, como
/// recomiendan los fabricantes para dos módulos).
const _dimmOrder = [1, 3, 0, 2];

ViewerScene layoutScene(
  BuildScene scene, {
  Set<String> errorOfferIds = const {},
}) {
  NodeState stateOf(ScenePart part) =>
      errorOfferIds.contains(part.offerId) ? NodeState.error : NodeState.normal;

  final pcCase = scene.partFor(ProductCategory.pcCase);
  final board = scene.partFor(ProductCategory.motherboard);
  final cpu = scene.partFor(ProductCategory.cpu);
  final cooling = scene.partFor(ProductCategory.cooling);
  final ram = scene.partFor(ProductCategory.ram);
  final gpu = scene.partFor(ProductCategory.gpu);
  final storage = scene.partFor(ProductCategory.storage);
  final psu = scene.partFor(ProductCategory.psu);

  // El gabinete crece con lo que admite: una gráfica que no cabe en él
  // sobresale, y así se ve la incompatibilidad.
  final depth = _clamp(
    (pcCase?.number('max_gpu_length_mm')?.toDouble() ?? 410) + 40,
    400,
    560,
  );
  final width = _clamp(
    (pcCase?.number('max_cooler_height_mm')?.toDouble() ?? 165) + 55,
    200,
    280,
  );
  const height = caseHeightMm;

  final layout = _boards[board?.text('form_factor')] ?? _atx;
  final ramSlots = board?.number('ram_slots')?.toInt();
  final dimms = ramSlots != null && ramSlots < layout.dimms.length
      ? layout.dimms.take(math.max(ramSlots, 1)).toList()
      : layout.dimms;

  final rearX = depth / 2 - 22;
  final topY = height / 2 - 28;
  final boardBack = -width / 2 + 16;
  final boardFront = boardBack + 3;
  (double, double) point((double, double) uv) => (rearX - uv.$1, topY - uv.$2);

  final nodes = <ViewerNode>[];
  final credits = <ModelCredit>{};
  PartModel? use(ScenePart part, {bool genericFits = true}) {
    final model = part.model;
    if (model == null || (model.generic && !genericFits)) return null;
    credits.add(model.credit);
    return model;
  }

  nodes.add(
    ViewerNode(
      id: 'case',
      part: pcCase?.offerId ?? '',
      kind: 'case',
      center: const [0, 0, 0],
      size: [depth, height, width],
      // Un gabinete genérico taparía el interior: solo modelos propios.
      model: pcCase == null ? null : use(pcCase, genericFits: false),
      state: pcCase == null ? NodeState.ghost : stateOf(pcCase),
    ),
  );

  if (board != null) {
    nodes.add(
      ViewerNode(
        id: board.offerId,
        part: board.offerId,
        kind: 'motherboard',
        center: [
          rearX - layout.width / 2,
          topY - layout.height / 2,
          boardBack + 20,
        ],
        size: [layout.width, layout.height, 40],
        align: const ['center', 'center', 'min'],
        model: use(board),
        state: stateOf(board),
        params: {
          'socket': [layout.socket.$1, layout.socket.$2],
          'dimms': dimms,
          'dimmV': layout.dimmV,
          'pcie': layout.pcie,
          'm2': [layout.m2.$1, layout.m2.$2],
        },
      ),
    );
  }

  final (socketX, socketY) = point(layout.socket);
  if (cpu != null) {
    nodes.add(
      ViewerNode(
        id: cpu.offerId,
        part: cpu.offerId,
        kind: 'cpu',
        center: [socketX, socketY, boardFront + 2.5],
        size: const [40, 40, 5],
        model: use(cpu),
        state: stateOf(cpu),
      ),
    );
  }

  if (cooling != null) {
    final coolerBase = boardFront + 5;
    if (cooling.text('cooling_type') == 'liquid') {
      final radiator = math.min(
        cooling.number('radiator_mm')?.toDouble() ?? defaultRadiatorMm,
        depth - 60,
      );
      nodes
        ..add(
          ViewerNode(
            id: '${cooling.offerId}#pump',
            part: cooling.offerId,
            kind: 'pump',
            center: [socketX, socketY, coolerBase + 19],
            size: const [60, 60, 38],
            state: stateOf(cooling),
          ),
        )
        ..add(
          ViewerNode(
            id: '${cooling.offerId}#radiator',
            part: cooling.offerId,
            kind: 'radiator',
            center: [
              -depth / 2 + 25 + radiator / 2,
              height / 2 - 30,
              width / 2 - 15 - 62.5,
            ],
            size: [radiator, 52, 125],
            state: stateOf(cooling),
          ),
        );
    } else {
      final coolerHeight =
          cooling.number('height_mm')?.toDouble() ?? defaultCoolerHeightMm;
      nodes.add(
        ViewerNode(
          id: cooling.offerId,
          part: cooling.offerId,
          kind: 'airCooler',
          center: [socketX, socketY, coolerBase + coolerHeight / 2],
          size: [110, 125, coolerHeight],
          // El modelo genérico no sabe si es de aire o líquida.
          model: use(cooling, genericFits: false),
          state: stateOf(cooling),
        ),
      );
    }
  }

  if (ram != null) {
    final count = (ram.number('modules')?.toInt() ?? 2).clamp(1, dimms.length);
    final slots = count >= dimms.length
        ? List.generate(dimms.length, (i) => i)
        : (_dimmOrder.where((i) => i < dimms.length).take(count).toList()
            ..sort());
    final model = use(ram);
    for (final (index, slot) in slots.indexed) {
      final (x, y) = point((dimms[slot], layout.dimmV));
      nodes.add(
        ViewerNode(
          id: '${ram.offerId}#${index + 1}',
          part: ram.offerId,
          kind: 'ram',
          center: [x, y, boardFront + 2 + 16],
          size: const [7, 133, 32],
          // Largo de la categoría (X) hacia arriba y alto (Y) hacia el vidrio.
          rotation: const [90, 90, 0],
          model: model,
          state: stateOf(ram),
        ),
      );
    }
  }

  if (gpu != null) {
    final length = gpu.number('length_mm')?.toDouble() ?? defaultGpuLengthMm;
    final (_, slotY) = point((0, layout.pcie.first));
    nodes.add(
      ViewerNode(
        id: gpu.offerId,
        part: gpu.offerId,
        kind: 'gpu',
        // El soporte va contra la trasera y la tarjeta cuelga de la ranura.
        center: [rearX + 14 - length / 2, slotY + 4 - 24, boardFront + 6 + 70],
        size: [length, 48, 140],
        align: const ['max', 'max', 'min'],
        // Alto de la tarjeta (Y) hacia el vidrio; ventiladores hacia abajo.
        rotation: const [90, 0, 0],
        model: use(gpu),
        state: stateOf(gpu),
      ),
    );
  }

  if (storage != null) {
    final model = use(storage, genericFits: false);
    final node = switch (storage.text('storage_type')) {
      'SATA_SSD' => ViewerNode(
        id: storage.offerId,
        part: storage.offerId,
        kind: 'ssd25',
        center: [-depth / 2 + 90, -height / 2 + 7.5, 0],
        size: const [100, 7, 70],
        model: model,
        state: stateOf(storage),
      ),
      'HDD' => ViewerNode(
        id: storage.offerId,
        part: storage.offerId,
        kind: 'hdd35',
        center: [-depth / 2 + 103.5, -height / 2 + 17, 0],
        size: const [147, 26, 102],
        model: model,
        state: stateOf(storage),
      ),
      _ => () {
        final (x, y) = point(layout.m2);
        return ViewerNode(
          id: storage.offerId,
          part: storage.offerId,
          kind: 'm2',
          center: [x, y, boardFront + 2],
          size: const [80, 22, 4],
          model: model,
          state: stateOf(storage),
        );
      }(),
    };
    nodes.add(node);
  }

  if (psu != null) {
    nodes.add(
      ViewerNode(
        id: psu.offerId,
        part: psu.offerId,
        kind: 'psu',
        center: [depth / 2 - 88, -height / 2 + 47, 0],
        size: const [160, 86, 150],
        model: use(psu),
        state: stateOf(psu),
      ),
    );
  }

  return ViewerScene(
    caseSize: [depth, height, width],
    nodes: nodes,
    credits: credits.toList(growable: false),
  );
}

double _clamp(double value, double min, double max) =>
    value < min ? min : (value > max ? max : value);
