import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/features/cart/cart_providers.dart';
import 'package:prueba01/features/catalog/domain/product.dart';
import 'package:prueba01/features/pc_builder/pc_builder_providers.dart';
import 'package:prueba01/features/pc_builder/presentation/part_picker_screen.dart';
import 'package:prueba01/features/pc_builder/presentation/pc_builder_screen.dart';
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

  Future<ProviderContainer> pumpBuilder(WidgetTester tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...bed.overrides,
          pcBuilderRepositoryProvider.overrideWithValue(engine),
          viewerHostProvider.overrideWithValue(viewer.build),
        ],
        child: MaterialApp(
          builder: (context, child) => child!,
          home: const PcBuilderScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    viewer.emit(const ViewerLoaded(failed: []));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(PcBuilderScreen)));
  }

  /// Al cambiar de vista, el visor se vuelve a crear y gira hasta que la
  /// página avisa que dibujó: se espera a que aparezca y se simula el aviso.
  Future<void> settleViewer(WidgetTester tester) async {
    final messages = viewer.messages.length;
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (viewer.messages.length > messages) {
        viewer.emit(const ViewerLoaded(failed: []));
        break;
      }
    }
    await tester.pumpAndSettle();
  }

  Future<void> show(WidgetTester tester, ProviderContainer container, String productId) async {
    container.read(prebuiltPreviewProvider.notifier).show(productId);
    await settleViewer(tester);
  }

  const gamerPro = ScriptedBuilderRepository.gamerPro;

  testWidgets('shows a prebuilt PC by sections and in 3D (RF-090)', (tester) async {
    final container = await pumpBuilder(tester);
    await show(tester, container, gamerPro);

    expect(find.text('COMPUTADOR ARMADO'), findsOneWidget);
    expect(find.text('PC GAMER PRO RYZEN 7 9700X / RTX 5070'), findsOneWidget);
    expect(find.text('AMD Ryzen 7 9700X'), findsOneWidget);
    expect(find.text('NVIDIA GeForce RTX 5070 12 GB'), findsOneWidget);
    expect(find.text('INCLUIDO'), findsNWidgets(2));
    expect(find.text('NO INCLUYE'), findsOneWidget, reason: 'la placa no está registrada');
    expect(find.text('Arrastra para girar y pellizca para acercar.'), findsOneWidget);

    expect(viewer.node('$gamerPro:gpu')!['url'], ScriptedBuilderRepository.gpuModel.url);
    expect(viewer.node('$gamerPro:ram#1'), isNotNull, reason: 'dos módulos de RAM');
    expect(viewer.node('$gamerPro:ram#2'), isNotNull);
  });

  testWidgets('does not touch the client build and returns to it', (tester) async {
    final container = await pumpBuilder(tester);
    await container
        .read(pcBuilderControllerProvider.notifier)
        .select(ProductCategory.cpu, ScriptedBuilderRepository.ryzen);
    await tester.pumpAndSettle();

    await show(tester, container, gamerPro);
    expect(viewer.node(ScriptedBuilderRepository.ryzen), isNull, reason: 'el visor muestra el armado');

    await tester.ensureVisible(find.text('VOLVER A MI CONFIGURACIÓN'));
    await tester.tap(find.text('VOLVER A MI CONFIGURACIÓN'));
    await settleViewer(tester);

    expect(container.read(prebuiltPreviewProvider), isNull);
    expect(container.read(pcBuilderControllerProvider).value!.selection, {
      ProductCategory.cpu: ScriptedBuilderRepository.ryzen,
    });
    expect(find.text('RYZEN 9 9950X'), findsOneWidget);
    expect(viewer.node(ScriptedBuilderRepository.ryzen), isNotNull);
  });

  testWidgets('the prebuilt PC is bought whole', (tester) async {
    final container = await pumpBuilder(tester);
    await show(tester, container, gamerPro);

    await tapAndSettle(tester, find.text('AGREGAR EL ARMADO AL CARRITO'));

    // Sin getById: su espera de latencia no avanza fuera de pump.
    final product = bed.products
        .productsIn(ProductCategory.prebuiltPc)
        .firstWhere((p) => p.id == gamerPro);
    final cart = await container.read(cartControllerProvider.future);
    expect(cart.items.single.offerId, product.bestOfferId);
  });

  testWidgets('tapping a component in 3D does not open a picker', (tester) async {
    final container = await pumpBuilder(tester);
    await show(tester, container, gamerPro);

    viewer.emit(const ViewerTap('$gamerPro:cpu'));
    await tester.pumpAndSettle();
    expect(find.byType(PartPickerScreen), findsNothing);
  });

  testWidgets('explains a prebuilt PC without registered components', (tester) async {
    final container = await pumpBuilder(tester);
    await show(tester, container, ScriptedBuilderRepository.office);

    expect(find.textContaining('todavía no tiene sus componentes registrados'), findsOneWidget);
    expect(find.text('Usa los gráficos integrados del procesador.'), findsOneWidget);
    expect(find.text('NO INCLUYE'), findsNWidgets(3));
  });
}
