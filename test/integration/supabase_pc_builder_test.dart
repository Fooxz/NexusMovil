// Prueba de integración del PC Builder contra el motor de reglas del Supabase
// local con seed.sql. Se salta sin configuración; ver
// supabase_catalog_test.dart para ejecutarla.
@Tags(['integration'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/core/config/env.dart';
import 'package:prueba01/core/errors/app_failure.dart';
import 'package:prueba01/features/catalog/domain/product.dart';
import 'package:prueba01/features/pc_builder/domain/pc_builder_models.dart';
import 'package:prueba01/features/pc_builder/data/supabase_pc_builder_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../support/integration_support.dart';

const _validBuild = [
  'off-tp-9950x', // AM5, 170 W, gráficos integrados
  'off-mp-b650ef', // AM5, ATX, DDR5
  'off-tp-vengeance32',
  'off-tp-990pro2tb',
  'off-mp-rm850x', // 850 W
  'off-mp-o11evo', // ATX, gráfica hasta 426 mm
  'off-tp-rtx5080', // 360 W, 304 mm
];

void main() {
  const env = AppEnv.fromEnvironment();
  final skip = integrationSkip(env);

  late SupabasePcBuilderRepository builder;

  setUpAll(() {
    if (skip != false) return;
    builder = SupabasePcBuilderRepository.fromClient(
      SupabaseClient(env.supabaseUrl, env.supabasePublishableKey),
    );
  });

  test('slots come from the backend', () async {
    final slots = await builder.getSlots();
    expect(slots.first.category, ProductCategory.cpu);
    expect(slots.where((s) => s.required).map((s) => s.label), [
      'Procesador',
      'Placa madre',
      'Memoria RAM',
      'Almacenamiento',
      'Fuente de poder',
      'Gabinete',
    ]);
  }, skip: skip);

  test('a compatible and complete build is valid and purchasable', () async {
    final validation = await builder.validate(_validBuild);

    expect(validation.valid, isTrue);
    expect(validation.purchasable, isTrue);
    expect(validation.issues, isEmpty);
    expect(validation.parts, hasLength(7));
  }, skip: skip);

  test('explains incompatibilities with the parts that cause them', () async {
    final validation = await builder.validate([
      for (final offer in _validBuild)
        offer == 'off-mp-b650ef'
            ? 'off-mp-z790hero'
            : offer == 'off-tp-rtx5080'
            ? 'off-tp-rtx5090'
            : offer,
    ]);

    expect(validation.valid, isFalse);
    expect(validation.errors.map((issue) => issue.ruleCode), [
      'cpu_motherboard_socket',
      'psu_power_budget',
    ]);
    expect(
      validation.errors.last.message,
      'Este equipo necesita una fuente de al menos 1100 W y la elegida es de 850 W.',
    );
    expect(validation.errors.last.offerIds, contains('off-tp-rtx5090'));
  }, skip: skip);

  test('candidates come compatible first, with the reason otherwise', () async {
    const build = ['off-tp-9950x', 'off-mp-rm850x', 'off-mp-o11evo'];
    final gpus = await builder.candidates(ProductCategory.gpu, build, cheapestFirst: false);
    final firstIncompatible = gpus.indexWhere((c) => !c.compatible);
    expect(gpus.take(firstIncompatible < 0 ? gpus.length : firstIncompatible),
        everyElement(predicate<BuilderCandidate>((c) => c.compatible)));

    final rtx5090 = await builder.candidates(ProductCategory.gpu, build, search: 'rtx 5090');
    final reference = rtx5090.firstWhere((c) => c.product.id == 'rtx-5090');
    expect(reference.compatible, isFalse);
    expect(reference.incompatibilityReason, contains('1100 W'));
  }, skip: skip);

  test('the 3D scene brings downloadable models and real sizes', () async {
    final scene = await builder.scene(_validBuild);

    final gpu = scene.partFor(ProductCategory.gpu)!;
    expect(gpu.number('length_mm'), 304);
    expect(gpu.model!.rotation, [0, 180, 0]);
    expect(gpu.model!.credit.license, 'CC-BY-3.0');
    expect(
      gpu.model!.url,
      '${env.supabaseUrl}/storage/v1/object/public/component-models/generic/gpu.glb',
    );
    expect(scene.partFor(ProductCategory.psu)!.model, isNull);
    expect(scene.partFor(ProductCategory.motherboard)!.text('form_factor'), 'ATX');

    // El archivo existe en Storage y se puede descargar sin sesión.
    final client = HttpClient();
    addTearDown(client.close);
    final response = await (await client.getUrl(Uri.parse(gpu.model!.url))).close();
    final bytes = await response.fold<int>(0, (sum, chunk) => sum + chunk.length);
    expect(response.statusCode, 200);
    expect(bytes, greaterThan(1000));
  }, skip: skip);

  test('rejects repeated slots', () async {
    await expectLater(
      builder.validate(['off-tp-9950x', 'off-tp-265k']),
      throwsA(isA<ValidationFailure>()),
    );
  }, skip: skip);
}
