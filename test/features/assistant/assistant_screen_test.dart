import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/core/errors/app_failure.dart';
import 'package:prueba01/features/assistant/assistant_providers.dart';
import 'package:prueba01/features/assistant/domain/assistant_models.dart';
import 'package:prueba01/features/assistant/presentation/assistant_screen.dart';
import 'package:prueba01/features/cart/cart_providers.dart';
import 'package:prueba01/features/catalog/domain/product.dart';
import 'package:prueba01/features/pc_builder/pc_builder_providers.dart';
import 'package:prueba01/screens/shell/main_shell.dart';
import 'package:prueba01/widgets/nexus_bottom_nav.dart';

import '../../support/assistant_test_support.dart';
import '../../support/auth_test_support.dart' show tapAndSettle, usePhoneViewport;
import '../../support/cart_test_support.dart';
import '../../support/pc_builder_test_support.dart';

void main() {
  late CartTestBed bed;
  late ScriptedBuilderRepository engine;
  NexusTab? selectedTab;

  setUp(() {
    bed = CartTestBed();
    engine = ScriptedBuilderRepository(bed.products, socketRule: false);
    selectedTab = null;
  });

  Future<(ProviderContainer, ScriptedAssistant)> pumpAssistant(
    WidgetTester tester,
    List<Object> script,
  ) async {
    usePhoneViewport(tester);
    final assistant = ScriptedAssistant(script);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...bed.overrides,
          assistantRepositoryProvider.overrideWithValue(assistant),
          pcBuilderRepositoryProvider.overrideWithValue(engine),
        ],
        child: MainShellScope(
          selectTab: (tab) => selectedTab = tab,
          child: const MaterialApp(home: AssistantScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(AssistantScreen)));
    return (container, assistant);
  }

  Future<void> ask(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tapAndSettle(tester, find.byTooltip('Enviar'));
  }

  Product product(ProductCategory category) => bed.products.productsIn(category).first;

  testWidgets('starts with suggestions and the AI notice (RNF-025)', (tester) async {
    final (_, assistant) = await pumpAssistant(tester, [
      const AssistantQuestion('¿Cuál es tu presupuesto aproximado?'),
    ]);

    expect(find.text('¿Qué computador necesitas?'), findsOneWidget);
    expect(find.textContaining('generadas con IA'), findsOneWidget);
    await tapAndSettle(tester, find.text(AssistantScreen.suggestions.first));

    expect(assistant.conversations.single.single.text, AssistantScreen.suggestions.first);
    expect(find.text(AssistantScreen.suggestions.first), findsOneWidget, reason: 'como mensaje');
    expect(find.text('¿Cuál es tu presupuesto aproximado?'), findsOneWidget);
  });

  testWidgets('a recommended product shows why and goes to the cart (RF-042)', (tester) async {
    final gpu = product(ProductCategory.gpu);
    final (container, _) = await pumpAssistant(tester, [
      AssistantRecommendation(
        'Para jugar en 4K te recomiendo esta tarjeta.',
        products: [RecommendedProduct(product: gpu, reason: '16 GB de video para 4K.')],
      ),
    ]);
    await ask(tester, 'Quiero jugar en 4K');

    expect(find.text(gpu.name), findsOneWidget);
    expect(find.text('16 GB de video para 4K.'), findsOneWidget);
    await tapAndSettle(tester, find.text('AGREGAR'));

    final cart = await container.read(cartControllerProvider.future);
    expect(cart.items.single.offerId, gpu.bestOfferId);
  });

  testWidgets('a parts build opens in the PC Builder, never in the cart (RF-089)', (tester) async {
    final offers = [ScriptedBuilderRepository.ryzen, ScriptedBuilderRepository.z790];
    final validation = await engine.validate(offers);
    final (container, _) = await pumpAssistant(tester, [
      AssistantRecommendation(
        'Te armé esta configuración.',
        build: ProposedBuild(reason: 'Potente para editar.', validation: validation),
      ),
    ]);
    await ask(tester, 'Ármame un PC por piezas');

    expect(find.text('CONFIGURACIÓN POR PIEZAS'), findsOneWidget);
    expect(find.text('Potente para editar.'), findsOneWidget);
    expect(find.textContaining(product(ProductCategory.cpu).name, findRichText: true), findsOneWidget);
    await tapAndSettle(tester, find.text('VER EN EL PC BUILDER (3D)'));

    expect(selectedTab, NexusTab.pcBuilder);
    final build = container.read(pcBuilderControllerProvider).value!;
    expect(build.selection, {
      ProductCategory.cpu: ScriptedBuilderRepository.ryzen,
      ProductCategory.motherboard: ScriptedBuilderRepository.z790,
    });
    expect((await container.read(cartControllerProvider.future)).items, isEmpty,
        reason: 'el cliente decide la compra');
  });

  testWidgets('the client can take the whole build to the cart in one tap', (tester) async {
    final offers = [ScriptedBuilderRepository.ryzen, ScriptedBuilderRepository.z790];
    final validation = await engine.validate(offers);
    final (container, _) = await pumpAssistant(tester, [
      AssistantRecommendation(
        'Te armé esta configuración.',
        build: ProposedBuild(reason: 'Potente para editar.', validation: validation),
      ),
    ]);
    await ask(tester, 'Ármame un PC por piezas');

    await tester.ensureVisible(find.text('AGREGAR TODO AL CARRITO'));
    await tapAndSettle(tester, find.text('AGREGAR TODO AL CARRITO'));

    final cart = await container.read(cartControllerProvider.future);
    expect(cart.items.map((item) => item.offerId), unorderedEquals(offers));
    expect(find.text('Agregamos las 2 piezas al carrito'), findsOneWidget);
    expect(find.text('VER CARRITO'), findsOneWidget);
    expect(selectedTab, isNull, reason: 'se queda en el asistente');
  });

  testWidgets('when the AI is down it offers the other ways to buy (RNF-018)', (tester) async {
    final (_, assistant) = await pumpAssistant(tester, [
      const AssistantUnavailableFailure(),
      const AssistantQuestion('¿Presupuesto?'),
    ]);
    await ask(tester, 'Un PC');

    expect(find.text(const AssistantUnavailableFailure().userMessage), findsOneWidget);
    await tapAndSettle(tester, find.text('PC BUILDER'));
    expect(selectedTab, NexusTab.pcBuilder);

    await tapAndSettle(tester, find.text('REINTENTAR'));
    expect(find.text('¿Presupuesto?'), findsOneWidget);
    expect(assistant.conversations, hasLength(2));
  });

  testWidgets('fits a 360 px phone with products and a build', (tester) async {
    final validation = await engine.validate([
      ScriptedBuilderRepository.ryzen,
      ScriptedBuilderRepository.z790,
      ScriptedBuilderRepository.rtx5080,
    ]);
    await pumpAssistant(tester, [
      AssistantRecommendation(
        'Mira estas opciones.',
        products: [
          RecommendedProduct(product: product(ProductCategory.gpu), reason: 'Rápida.'),
          RecommendedProduct(product: product(ProductCategory.cpu), reason: 'Muchos núcleos.'),
        ],
        build: ProposedBuild(reason: 'Equilibrada.', validation: validation),
      ),
    ]);
    tester.view.physicalSize = const Size(360, 740);
    await ask(tester, 'Un PC para todo');

    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the assistant has its own tab in the middle of the bar', (tester) async {
    NexusTab? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: NexusBottomNav(
            current: NexusTab.home,
            onTap: (tab) => tapped = tab,
          ),
        ),
      ),
    );

    await tester.tap(find.text('ASISTENTE'));
    expect(tapped, NexusTab.assistant);
    expect(NexusTab.assistant.tabIndex, 2);
  });
}
