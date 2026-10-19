import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/features/catalog/domain/product.dart';
import 'package:prueba01/features/pc_builder/pc_builder_providers.dart';
import 'package:prueba01/features/pc_builder/presentation/part_picker_screen.dart';
import 'package:prueba01/features/pc_builder/presentation/pc_builder_screen.dart';
import 'package:prueba01/features/pc_builder/presentation/viewer/pc_viewer.dart';
import 'package:prueba01/features/pc_builder/presentation/viewer/viewer_host.dart';

import '../../support/auth_test_support.dart' show tapAndSettle, usePhoneViewport;
import '../../support/cart_test_support.dart';
import '../../support/pc_builder_test_support.dart';

void main() {
  late CartTestBed bed;
  late ScriptedBuilderRepository engine;
  late FakeViewer viewer;

  setUp(() {
    bed = CartTestBed();
    engine = ScriptedBuilderRepository(bed.products);
    viewer = FakeViewer();
  });

  Future<ProviderContainer> pumpBuilder(
    WidgetTester tester, {
    bool supported = true,
    bool drawn = true,
  }) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...bed.overrides,
          pcBuilderRepositoryProvider.overrideWithValue(engine),
          viewerHostProvider.overrideWithValue(supported ? viewer.build : null),
        ],
        child: MaterialApp(
          builder: (context, child) => child!,
          home: const PcBuilderScreen(),
        ),
      ),
    );
    // El indicador del visor gira hasta que la página avisa que dibujó.
    await tester.pump();
    await tester.pump();
    if (supported && drawn) viewer.emit(const ViewerLoaded(failed: []));
    if (drawn) await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(PcBuilderScreen)));
  }

  Future<void> select(
    WidgetTester tester,
    ProviderContainer container,
    ProductCategory category,
    String offerId,
  ) async {
    await container.read(pcBuilderControllerProvider.notifier).select(category, offerId);
    await tester.pumpAndSettle();
  }

  Finder spinnerInViewer() => find.descendant(
    of: find.byType(PcViewer),
    matching: find.byType(CircularProgressIndicator),
  );

  testWidgets('shows the build in 3D and keeps it in sync (RF-090)', (tester) async {
    final container = await pumpBuilder(tester, drawn: false);

    expect(viewer.node('case')!['state'], 'ghost', reason: 'sin gabinete, uno de referencia');
    expect(spinnerInViewer(), findsOneWidget, reason: 'mientras el visor dibuja');
    viewer.emit(const ViewerLoaded(failed: []));
    await tester.pumpAndSettle();
    expect(spinnerInViewer(), findsNothing);

    await select(tester, container, ProductCategory.cpu, ScriptedBuilderRepository.ryzen);
    expect(viewer.node(ScriptedBuilderRepository.ryzen)!['kind'], 'cpu');
    expect(viewer.node(ScriptedBuilderRepository.ryzen)!['state'], 'normal');

    await select(tester, container, ProductCategory.motherboard, ScriptedBuilderRepository.z790);
    expect(viewer.node(ScriptedBuilderRepository.ryzen)!['state'], 'error',
        reason: 'las piezas incompatibles se marcan');
    expect(viewer.node(ScriptedBuilderRepository.z790)!['state'], 'error');
    expect(engine.sceneCalls.last, [
      ScriptedBuilderRepository.ryzen,
      ScriptedBuilderRepository.z790,
    ]);
  });

  testWidgets('tapping a part in 3D opens its picker', (tester) async {
    final container = await pumpBuilder(tester);
    await select(tester, container, ProductCategory.cpu, ScriptedBuilderRepository.ryzen);

    viewer.emit(const ViewerTap(''));
    await tester.pumpAndSettle();
    expect(find.byType(PartPickerScreen), findsNothing,
        reason: 'el gabinete de referencia no es una pieza');

    viewer.emit(const ViewerTap(ScriptedBuilderRepository.ryzen));
    await tester.pumpAndSettle();
    final picker = tester.widget<PartPickerScreen>(find.byType(PartPickerScreen));
    expect(picker.slot.category, ProductCategory.cpu);
  });

  testWidgets('credits the CC BY models it shows', (tester) async {
    final container = await pumpBuilder(tester);
    expect(find.text('Créditos de los modelos 3D'), findsNothing);

    await select(tester, container, ProductCategory.gpu, ScriptedBuilderRepository.rtx5080);
    expect(viewer.node(ScriptedBuilderRepository.rtx5080)!['url'],
        ScriptedBuilderRepository.gpuModel.url);
    await tapAndSettle(tester, find.text('Créditos de los modelos 3D'));

    expect(find.textContaining('"Graphics card" de pgonarg'), findsOneWidget);
    expect(find.textContaining('CC BY 3.0'), findsOneWidget);
    expect(find.textContaining('https://poly.pizza/m/i45v5trpyR'), findsOneWidget);
  });

  testWidgets('explains models that did not load and missing WebGL', (tester) async {
    await pumpBuilder(tester);

    viewer.emit(const ViewerLoaded(failed: ['off-x']));
    await tester.pump();
    expect(find.text('Algunos modelos no cargaron: esas piezas se ven genéricas.'), findsOneWidget);

    viewer.emit(const ViewerFailure('webgl'));
    await tester.pump();
    expect(find.text('Este dispositivo no puede mostrar la vista 3D.'), findsOneWidget);
    expect(find.byKey(const Key('fake-viewer')), findsNothing);
  });

  testWidgets('says where 3D is available on other platforms', (tester) async {
    await pumpBuilder(tester, supported: false);

    expect(find.text('La vista 3D está disponible en Android, iOS y la web.'), findsOneWidget);
    expect(find.text('Elegir procesador'), findsOneWidget, reason: 'el armador funciona igual');
  });
}
