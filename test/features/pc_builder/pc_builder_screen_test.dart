import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/features/cart/cart_providers.dart';
import 'package:prueba01/features/catalog/domain/product.dart';
import 'package:prueba01/features/pc_builder/pc_builder_providers.dart';
import 'package:prueba01/features/pc_builder/presentation/pc_builder_screen.dart';

import '../../support/auth_test_support.dart' show tapAndSettle, usePhoneViewport;
import '../../support/cart_test_support.dart';
import '../../support/pc_builder_test_support.dart';

void main() {
  late CartTestBed bed;
  late ScriptedBuilderRepository engine;

  setUp(() {
    bed = CartTestBed();
    engine = ScriptedBuilderRepository(bed.products);
  });

  Future<ProviderContainer> pumpBuilder(WidgetTester tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...bed.overrides,
          pcBuilderRepositoryProvider.overrideWithValue(engine),
        ],
        child: MaterialApp(
          builder: (context, child) => child!,
          home: const PcBuilderScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(PcBuilderScreen)));
  }

  testWidgets('starts empty and tells where to begin', (tester) async {
    await pumpBuilder(tester);

    expect(
      find.text('Empieza por el procesador: el resto de piezas depende de él.'),
      findsOneWidget,
    );
    expect(find.text('0 de 2 piezas obligatorias'), findsOneWidget);
    expect(find.text('OBLIGATORIA'), findsNWidgets(2));
    expect(find.text('OPCIONAL'), findsOneWidget);
  });

  testWidgets('choosing parts in the picker updates the build', (tester) async {
    await pumpBuilder(tester);

    await tapAndSettle(tester, find.text('Elegir procesador'));
    expect(find.text('PROCESADOR'), findsOneWidget, reason: 'selector abierto');
    await tapAndSettle(tester, find.text('ELEGIR').first);

    expect(find.text('RYZEN 9 9950X'), findsOneWidget);
    expect(find.text('Falta: Placa madre.'), findsOneWidget);
    expect(find.text('1 de 2 piezas obligatorias'), findsOneWidget);
    expect(engine.validateCalls.last, [ScriptedBuilderRepository.ryzen]);
  });

  testWidgets('explains an incompatibility on the parts that cause it', (tester) async {
    final container = await pumpBuilder(tester);
    final builder = container.read(pcBuilderControllerProvider.notifier);
    await builder.select(ProductCategory.cpu, ScriptedBuilderRepository.ryzen);
    await builder.select(ProductCategory.motherboard, ScriptedBuilderRepository.z790);
    await tester.pumpAndSettle();

    expect(find.text('Hay 1 incompatibilidad. Revisa las piezas marcadas.'), findsOneWidget);
    expect(find.text(ScriptedBuilderRepository.socketMessage), findsNWidgets(2),
        reason: 'en el procesador y en la placa');
    expect(find.text('Ver alternativas'), findsNWidgets(2));
    final addAll = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('AGREGAR TODO AL CARRITO'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );
    expect(addAll.onPressed, isNull, reason: 'no se lleva una configuración inválida');
  });

  testWidgets('the picker shows why an option does not fit', (tester) async {
    final container = await pumpBuilder(tester);
    await container
        .read(pcBuilderControllerProvider.notifier)
        .select(ProductCategory.cpu, ScriptedBuilderRepository.ryzen);
    await tester.pumpAndSettle();

    await tapAndSettle(tester, find.text('Elegir placa madre'));

    expect(find.text('NO COMPATIBLE'), findsOneWidget);
    expect(find.text(ScriptedBuilderRepository.socketMessage), findsOneWidget);
  });

  testWidgets('a valid build goes to the cart in one tap (RF-051)', (tester) async {
    // El mock solo tiene ese CPU y esa placa: se desactiva la regla de socket
    // para tener una configuración completa, compatible y con stock.
    engine = ScriptedBuilderRepository(bed.products, socketRule: false);
    final container = await pumpBuilder(tester);
    final builder = container.read(pcBuilderControllerProvider.notifier);
    await builder.select(ProductCategory.cpu, ScriptedBuilderRepository.ryzen);
    await builder.select(ProductCategory.motherboard, ScriptedBuilderRepository.z790);
    await builder.select(ProductCategory.gpu, ScriptedBuilderRepository.rtx5080);
    await tester.pumpAndSettle();
    expect(find.text('Configuración compatible y completa.'), findsOneWidget);
    // 2.596.000 + 5.999.900 + 1.699.000
    expect(find.text('\$10.294.900'), findsOneWidget);

    await tapAndSettle(tester, find.text('AGREGAR TODO AL CARRITO'));

    expect(find.text('Agregamos las 3 piezas al carrito'), findsOneWidget);
    // El carrito no tiene quien lo escuche en esta prueba: se espera a que
    // termine de recalcularse.
    final cart = await container.read(cartControllerProvider.future);
    expect(cart.items.map((item) => item.offerId), [
      ScriptedBuilderRepository.ryzen,
      ScriptedBuilderRepository.z790,
      ScriptedBuilderRepository.rtx5080,
    ]);
  });

  testWidgets('fits a 360 px phone with parts, issues and the picker', (tester) async {
    final container = await pumpBuilder(tester);
    tester.view.physicalSize = const Size(360, 740);
    final builder = container.read(pcBuilderControllerProvider.notifier);
    await builder.select(ProductCategory.cpu, ScriptedBuilderRepository.ryzen);
    await builder.select(ProductCategory.motherboard, ScriptedBuilderRepository.z790);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tapAndSettle(tester, find.text('Ver alternativas').first);
    expect(tester.takeException(), isNull);
  });

  testWidgets('starting over clears the build', (tester) async {
    final container = await pumpBuilder(tester);
    await container
        .read(pcBuilderControllerProvider.notifier)
        .select(ProductCategory.cpu, ScriptedBuilderRepository.ryzen);
    await tester.pumpAndSettle();

    await tapAndSettle(tester, find.text('Empezar de nuevo'));

    expect(container.read(pcBuilderControllerProvider).value!.isEmpty, isTrue);
    expect(find.text('RYZEN 9 9950X'), findsNothing);
    expect(container.read(cartControllerProvider).value?.isEmpty ?? true, isTrue);
  });
}
