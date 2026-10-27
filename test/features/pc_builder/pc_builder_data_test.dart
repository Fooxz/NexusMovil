import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/core/errors/app_failure.dart';
import 'package:prueba01/features/catalog/data/mock_product_repository.dart';
import 'package:prueba01/features/catalog/domain/product.dart';
import 'package:prueba01/features/pc_builder/data/mock_pc_builder_repository.dart';
import 'package:prueba01/features/pc_builder/data/pc_builder_json.dart';
import 'package:prueba01/features/pc_builder/data/supabase_pc_builder_repository.dart';
import 'package:prueba01/features/pc_builder/domain/pc_builder_models.dart';

import '../../support/contract_fixtures.dart';

/// Respuesta de `validate_build` (API_CONTRATO, parte 3).
const validationJson = {
  'valid': false,
  'purchasable': false,
  'parts': [
    {
      'offerId': 'off-tp-9950x',
      'category': 'cpu',
      'productId': 'ryzen-9-9950x',
      'productName': 'RYZEN 9 9950X',
      'brand': 'AMD',
      'providerName': 'TecnoPartes',
      'priceCents': 259600000,
      'available': true,
      'imageUrl': null,
    },
    {
      'offerId': 'off-mp-z790hero',
      'category': 'motherboard',
      'productId': 'rog-maximus-z790-hero',
      'productName': 'ROG MAXIMUS Z790 HERO',
      'brand': 'ASUS',
      'providerName': 'Mundo PC',
      'priceCents': 599990000,
      'available': true,
      'imageUrl': null,
    },
  ],
  'issues': [
    {
      'ruleCode': 'cpu_motherboard_socket',
      'severity': 'error',
      'message': 'El procesador usa el socket AM5 y la placa madre el LGA1700: no encajan entre sí.',
      'offerIds': ['off-tp-9950x', 'off-mp-z790hero'],
    },
    {
      'ruleCode': 'gpu_case_length',
      'severity': 'warning',
      'message': 'No pudimos verificar…',
      'offerIds': <String>[],
    },
  ],
  'missingSlots': [
    {'category': 'ram', 'label': 'Memoria RAM'},
    {'category': 'otraCosa', 'label': 'Desconocida'},
  ],
  'totalCents': 859590000,
};

void main() {
  test('reads a validation of the contract', () {
    final validation = buildValidationFromJson(validationJson);

    expect(validation.valid, isFalse);
    expect(validation.parts.map((p) => p.category), [
      ProductCategory.cpu,
      ProductCategory.motherboard,
    ]);
    expect(validation.errors.single.offerIds, ['off-tp-9950x', 'off-mp-z790hero']);
    expect(validation.warnings.single.ruleCode, 'gpu_case_length');
    expect(validation.issuesFor('off-mp-z790hero'), hasLength(1));
    expect(validation.partFor(ProductCategory.motherboard)?.providerName, 'Mundo PC');
    expect(
      validation.missingSlots.map((s) => s.label),
      ['Memoria RAM'],
      reason: 'omite categorías que la app no conoce',
    );
  });

  test('reads slots and candidates', () {
    final slots = builderSlotsFromJson([
      {'category': 'cpu', 'label': 'Procesador', 'required': true},
      {'category': 'gpu', 'label': 'Tarjeta gráfica', 'required': false},
    ]);
    expect(slots.map((s) => '${s.category.name}:${s.required}'), ['cpu:true', 'gpu:false']);

    final candidates = builderCandidatesFromJson([
      {...contractDetailFixture, 'compatible': true},
      {
        ...contractDetailFixture,
        'id': 'otra',
        'compatible': false,
        'incompatibilityReason': 'No encaja.',
      },
    ]);
    expect(candidates.map((c) => c.compatible), [true, false]);
    expect(candidates.last.incompatibilityReason, 'No encaja.');
    expect(() => buildValidationFromJson({'valid': true}), throwsFormatException);
  });

  test('the Supabase repository sends the RPC parameters', () async {
    final calls = <(String, Map<String, Object?>)>[];
    final repository = SupabasePcBuilderRepository((function, params) async {
      calls.add((function, params));
      return switch (function) {
        'validate_build' => validationJson,
        'get_builder_candidates' => <Object?>[],
        _ => <Object?>[],
      };
    });

    await repository.validate(['off-tp-9950x', 'off-mp-z790hero']);
    await repository.candidates(ProductCategory.pcCase, ['off-tp-9950x']);
    await repository.getSlots();

    expect(calls.map((call) => call.$1), [
      'validate_build',
      'get_builder_candidates',
      'get_builder_slots',
    ]);
    expect(calls[0].$2, {
      'offer_ids': ['off-tp-9950x', 'off-mp-z790hero'],
    });
    expect(calls[1].$2, {
      'category': 'pcCase',
      'offer_ids': ['off-tp-9950x'],
      'max_items': 30,
      'sort': 'priceAsc',
      'page': 0,
    });
  });

  group('mock without backend', () {
    final repository = MockPcBuilderRepository(
      MockProductRepository(latency: Duration.zero),
    );

    test('says it does not check compatibility instead of claiming it', () async {
      final validation = await repository.validate([
        'mock-offer-ryzen-9-9950x',
        'mock-offer-rog-maximus-z790-hero',
      ]);

      // En el backend estas dos piezas no encajan; el mock no puede saberlo
      // y lo dice.
      expect(validation.errors, isEmpty);
      expect(validation.warnings.single.message, MockPcBuilderRepository.noRulesMessage);
      expect(validation.valid, isFalse, reason: 'faltan piezas obligatorias');
    });

    test('applies one part per slot and rejects unknown offers', () async {
      await expectLater(
        repository.validate(['mock-offer-ryzen-9-9950x', 'mock-offer-ryzen-9-9950x']),
        throwsA(isA<ValidationFailure>()),
      );
      await expectLater(
        repository.validate(['no-existe']),
        throwsA(isA<NotFoundFailure>()),
      );
    });

    test('lists candidates of the slot with stock first', () async {
      final candidates = await repository.candidates(ProductCategory.cooling, const []);
      expect(candidates.map((c) => c.product.id), [
        'cooler-master-elite-liquid-360',
        'kraken-elite-360',
      ]);
      expect(candidates.last.inStock, isFalse);
    });

    test('searches, sorts and pages the candidates', () async {
      final byName = await repository.candidates(ProductCategory.gpu, const [], search: '5080');
      expect(byName.map((c) => c.product.id), ['rtx-5080']);

      final expensiveFirst =
          await repository.candidates(ProductCategory.gpu, const [], cheapestFirst: false);
      expect(expensiveFirst.first.product.id, 'rtx-5090');

      expect(await repository.candidates(ProductCategory.gpu, const [], page: 1), isEmpty);
    });
  });

  test('BuildValidation.empty has nothing to show', () {
    const empty = BuildValidation.empty();
    expect(empty.parts, isEmpty);
    expect(empty.purchasable, isFalse);
  });
}
