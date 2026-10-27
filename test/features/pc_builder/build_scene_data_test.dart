import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/core/errors/app_failure.dart';
import 'package:prueba01/features/catalog/data/mock_product_repository.dart';
import 'package:prueba01/features/catalog/domain/product.dart';
import 'package:prueba01/features/pc_builder/data/build_scene_json.dart';
import 'package:prueba01/features/pc_builder/data/mock_pc_builder_repository.dart';
import 'package:prueba01/features/pc_builder/data/supabase_pc_builder_repository.dart';
import 'package:prueba01/features/pc_builder/presentation/viewer/viewer_host.dart';


/// Respuesta de `get_build_scene` (API_CONTRATO, parte 3).
const sceneJson = {
  'parts': [
    {
      'offerId': 'off-tp-rtx5080',
      'category': 'gpu',
      'productName': 'NVIDIA RTX 5080',
      'attributes': {'length_mm': 304},
      'model': {
        'path': 'generic/gpu.glb',
        'rotation': [0, 180, 0],
        'generic': true,
        'title': 'Graphics card',
        'author': 'pgonarg',
        'license': 'CC-BY-3.0',
        'sourceUrl': 'https://poly.pizza/m/i45v5trpyR',
      },
    },
    {
      'offerId': 'off-mp-b650ef',
      'category': 'motherboard',
      'productName': 'ROG STRIX B650E-F',
      'attributes': {'form_factor': 'ATX', 'ram_slots': 4},
      'model': null,
    },
  ],
};

String bucket(String path) => 'https://storage.test/component-models/$path';

void main() {
  test('reads the scene of the contract and builds the model URLs', () {
    final scene = buildSceneFromJson(sceneJson, modelUrl: bucket);

    final gpu = scene.partFor(ProductCategory.gpu)!;
    expect(gpu.number('length_mm'), 304);
    expect(gpu.model!.url, 'https://storage.test/component-models/generic/gpu.glb');
    expect(gpu.model!.rotation, [0, 180, 0]);
    expect(gpu.model!.generic, isTrue);
    expect(gpu.model!.credit.author, 'pgonarg');
    expect(gpu.model!.credit.requiresAttribution, isTrue);

    final board = scene.partFor(ProductCategory.motherboard)!;
    expect(board.model, isNull);
    expect(board.text('form_factor'), 'ATX');
  });

  test('a malformed model is ignored and the part is generated', () {
    final scene = buildSceneFromJson({
      'parts': [
        {
          'offerId': 'x',
          'category': 'gpu',
          'productName': 'X',
          'model': {'path': 'x.glb', 'rotation': [0, 0]},
        },
        {'offerId': 'y', 'category': 'speakers', 'productName': 'Y'},
      ],
    }, modelUrl: bucket);

    expect(scene.parts.single.model, isNull, reason: 'y la categoría desconocida se omite');
    expect(() => buildSceneFromJson({'items': []}, modelUrl: bucket), throwsFormatException);
  });

  test('the Supabase repository asks for the scene of the build', () async {
    final calls = <(String, Map<String, Object?>)>[];
    final repository = SupabasePcBuilderRepository((function, params) async {
      calls.add((function, params));
      return sceneJson;
    }, modelUrl: bucket);

    final scene = await repository.scene(['off-tp-rtx5080', 'off-mp-b650ef']);

    expect(calls.single.$1, 'get_build_scene');
    expect(calls.single.$2, {
      'offer_ids': ['off-tp-rtx5080', 'off-mp-b650ef'],
    });
    expect(scene.parts.first.model!.url, bucket('generic/gpu.glb'));
  });

  test('a bad response is an unexpected failure', () async {
    final repository = SupabasePcBuilderRepository((_, _) async => {'nope': 1});
    await expectLater(repository.scene(const []), throwsA(isA<UnexpectedFailure>()));
  });

  test('the mock has no models: every part is generated', () async {
    final products = MockProductRepository(latency: Duration.zero);
    final repository = MockPcBuilderRepository(products);
    final offer = products.productsIn(ProductCategory.gpu).first.bestOfferId!;

    final scene = await repository.scene([offer]);

    expect(scene.parts.single.category, ProductCategory.gpu);
    expect(scene.parts.single.model, isNull);
  });

  group('viewer events', () {
    test('are read from the page messages', () {
      expect(ViewerEvent.parse('{"type":"ready"}'), isA<ViewerReady>());
      expect(
        (ViewerEvent.parse('{"type":"loaded","failed":["a"]}')! as ViewerLoaded).failed,
        ['a'],
      );
      expect((ViewerEvent.parse('{"type":"tap","part":"off-1"}')! as ViewerTap).part, 'off-1');
      expect(ViewerEvent.parse('{"type":"error","message":"webgl"}'), isA<ViewerFailure>());
    });

    test('unknown or broken messages are ignored', () {
      expect(ViewerEvent.parse('{"type":"other"}'), isNull);
      expect(ViewerEvent.parse('no es json'), isNull);
    });
  });
}
