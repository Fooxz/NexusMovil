// Escena de ejemplo para revisar el visor en un navegador, sin la app:
//
//   dart run tool/viewer/demo_scene.dart [url-base-de-modelos] [aire|liquida|sin]
//
// Imprime el fragmento `#scene=...` que se agrega a la dirección de
// assets/viewer/viewer.html servido por HTTP (ver tool/viewer/README.md).
import 'dart:io';

import 'package:prueba01/features/catalog/domain/product.dart';
import 'package:prueba01/features/pc_builder/domain/build_scene.dart';
import 'package:prueba01/features/pc_builder/presentation/viewer/scene_layout.dart';

void main(List<String> args) {
  final base = args.isNotEmpty ? args[0] : null;
  final cooling = args.length > 1 ? args[1] : 'aire';
  PartModel? model(String file, ModelCredit credit) => base == null
      ? null
      : PartModel(url: '$base/$file', credit: credit, generic: true);
  const cc0 = ModelCredit(title: 'Modelo', author: 'iPoly3D', license: 'CC0-1.0');
  const ccBy = ModelCredit(title: 'Graphics card', author: 'pgonarg', license: 'CC-BY-3.0');

  final scene = BuildScene(
    parts: [
      ScenePart(
        offerId: 'off-tp-9950x',
        category: ProductCategory.cpu,
        productName: 'Ryzen 9 9950X',
        model: model('generic/cpu.glb', cc0),
      ),
      const ScenePart(
        offerId: 'off-mp-b650ef',
        category: ProductCategory.motherboard,
        productName: 'ROG Strix B650E-F',
        attributes: {'form_factor': 'ATX', 'ram_slots': 4},
      ),
      ScenePart(
        offerId: 'off-tp-vengeance32',
        category: ProductCategory.ram,
        productName: 'Vengeance 32 GB',
        model: model('generic/ram.glb', cc0),
        attributes: const {'modules': 2},
      ),
      ScenePart(
        offerId: 'off-tp-rtx5080',
        category: ProductCategory.gpu,
        productName: 'RTX 5080',
        model: model('generic/gpu.glb', ccBy),
        attributes: const {'length_mm': 304},
      ),
      const ScenePart(
        offerId: 'off-tp-990pro2tb',
        category: ProductCategory.storage,
        productName: '990 Pro',
        attributes: {'storage_type': 'NVMe'},
      ),
      const ScenePart(
        offerId: 'off-mp-rm850x',
        category: ProductCategory.psu,
        productName: 'RM850x',
      ),
      const ScenePart(
        offerId: 'off-mp-o11evo',
        category: ProductCategory.pcCase,
        productName: 'O11 Dynamic EVO',
        attributes: {'max_gpu_length_mm': 426, 'max_cooler_height_mm': 167},
      ),
      if (cooling != 'sin')
        ScenePart(
          offerId: 'off-cooler',
          category: ProductCategory.cooling,
          productName: 'Disipador',
          attributes: cooling == 'liquida'
              ? const {'cooling_type': 'liquid', 'radiator_mm': 360}
              : const {'cooling_type': 'air', 'height_mm': 158},
        ),
    ],
  );
  stdout.writeln('#scene=${Uri.encodeComponent(layoutScene(scene).toMessage())}');
}
