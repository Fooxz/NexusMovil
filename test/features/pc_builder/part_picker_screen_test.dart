import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/features/catalog/domain/product.dart';
import 'package:prueba01/features/pc_builder/domain/pc_builder_models.dart';
import 'package:prueba01/features/pc_builder/pc_builder_providers.dart';
import 'package:prueba01/features/pc_builder/presentation/part_picker_screen.dart';

import '../../support/auth_test_support.dart' show tapAndSettle, usePhoneViewport;
import '../../support/cart_test_support.dart';
import '../../support/pc_builder_test_support.dart';

/// Catálogo grande de gráficas: 45 sin buscar, 2 con cualquier búsqueda.
class _ManyGpus extends ScriptedBuilderRepository {
  _ManyGpus(super.products);

  final requests = <({String search, bool cheapestFirst, int page})>[];

  @override
  Future<List<BuilderCandidate>> candidates(
    ProductCategory category,
    List<String> offerIds, {
    String search = '',
    bool cheapestFirst = true,
    int page = 0,
  }) async {
    requests.add((search: search, cheapestFirst: cheapestFirst, page: page));
    final count = search.isEmpty ? 45 : 2;
    final all = [
      for (var i = 0; i < count; i++)
        BuilderCandidate(
          product: Product(
            id: 'gpu-$i',
            name: '${search.isEmpty ? 'GPU' : search.toUpperCase()} $i',
            brand: 'Marca',
            category: ProductCategory.gpu,
            priceCents: (cheapestFirst ? 100 + i : 1000 - i) * 1000000,
            stockLevel: StockLevel.stable,
            bestOfferId: 'off-gpu-$i',
          ),
          compatible: true,
        ),
    ];
    return all.skip(page * 30).take(30).toList();
  }
}

void main() {
  late CartTestBed bed;
  late _ManyGpus engine;

  setUp(() {
    bed = CartTestBed();
    engine = _ManyGpus(bed.products);
  });

  Future<void> pumpPicker(WidgetTester tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...bed.overrides,
          pcBuilderRepositoryProvider.overrideWithValue(engine),
        ],
        child: const MaterialApp(
          home: PartPickerScreen(
            slot: BuilderSlot(category: ProductCategory.gpu, label: 'Tarjeta gráfica', required: false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('loads 30 parts and the next page with "Ver más"', (tester) async {
    await pumpPicker(tester);
    final list = find
        .descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable))
        .first;

    expect(find.text('GPU 0'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Ver más'), 400, scrollable: list);
    await tapAndSettle(tester, find.text('Ver más'));

    expect(engine.requests.map((r) => r.page), [0, 1]);
    await tester.scrollUntilVisible(find.text('GPU 44'), 400, scrollable: list);
    expect(find.text('GPU 44'), findsOneWidget);
    expect(find.text('Ver más'), findsNothing, reason: 'la última página vino incompleta');
  });

  testWidgets('searches by name after a pause and keeps the sort', (tester) async {
    await pumpPicker(tester);

    await tapAndSettle(tester, find.text('Mayor precio'));
    expect(engine.requests.last, (search: '', cheapestFirst: false, page: 0));

    await tester.enterText(find.byType(TextFormField), 'rtx 5090');
    await tester.pump(const Duration(milliseconds: 100));
    expect(engine.requests, hasLength(2), reason: 'espera a que termine de escribir');
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(engine.requests.last, (search: 'rtx 5090', cheapestFirst: false, page: 0));
    expect(find.text('RTX 5090 0'), findsOneWidget);
    expect(find.text('Ver más'), findsNothing);
  });

  testWidgets('explains when the search finds nothing', (tester) async {
    engine = _EmptySearch(bed.products);
    await pumpPicker(tester);

    await tester.enterText(find.byType(TextFormField), 'monitor');
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(find.text('No encontramos piezas con "monitor".'), findsOneWidget);
  });
}

class _EmptySearch extends _ManyGpus {
  _EmptySearch(super.products);

  @override
  Future<List<BuilderCandidate>> candidates(
    ProductCategory category,
    List<String> offerIds, {
    String search = '',
    bool cheapestFirst = true,
    int page = 0,
  }) async => search.isEmpty ? super.candidates(category, offerIds) : const [];
}
