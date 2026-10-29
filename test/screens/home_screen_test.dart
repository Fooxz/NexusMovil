import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/features/catalog/presentation/catalog_offer_card.dart';
import 'package:prueba01/screens/shell/main_shell.dart';

import '../support/auth_test_support.dart' show tapAndSettle, usePhoneViewport;

Future<void> _pumpShell(WidgetTester tester) async {
  usePhoneViewport(tester);
  await tester.pumpWidget(
    ProviderScope(retry: (retryCount, error) => null, child: const MaterialApp(home: MainShell())),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('el inicio muestra categorías, ofertas reales del catálogo y las tiendas', (tester) async {
    await _pumpShell(tester);

    expect(find.text('Entregar en'), findsOneWidget);
    expect(find.text('Inicia sesión para comprar'), findsOneWidget, reason: 'sin sesión no hay dirección');
    expect(find.text('CATEGORÍAS'), findsOneWidget);
    expect(find.text('OFERTAS'), findsOneWidget);
    expect(find.textContaining('HASTA -'), findsOneWidget, reason: 'el mayor descuento de las ofertas');
    expect(find.byType(CatalogOfferCard, skipOffstage: false), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('TIENDAS'),
      300,
      scrollable: find.ancestor(of: find.text('CATEGORÍAS'), matching: find.byType(Scrollable)).first,
    );
    expect(find.text('TIENDAS'), findsOneWidget);
  });

  testWidgets('una categoría del inicio abre el catálogo filtrado', (tester) async {
    await _pumpShell(tester);

    await tapAndSettle(tester, find.text('GPU').first);
    expect(find.text('CATÁLOGO COMPLETO'), findsOneWidget);
  });

  testWidgets('el menú lateral del cliente funciona: abre secciones y ofrece iniciar sesión', (tester) async {
    await _pumpShell(tester);

    await tapAndSettle(tester, find.byTooltip('Abrir menú'));
    expect(find.text('Hola, invitado'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);

    await tapAndSettle(tester, find.descendant(of: find.byType(Drawer), matching: find.text('Catálogo')));
    expect(find.byType(Drawer), findsNothing, reason: 'el menú se cierra');
    expect(find.text('CATÁLOGO COMPLETO'), findsOneWidget);

    // El catálogo también tiene el botón del menú.
    await tapAndSettle(tester, find.byTooltip('Abrir menú'));
    await tapAndSettle(tester, find.descendant(of: find.byType(Drawer), matching: find.text('PC Builder')));
    expect(find.text('PC BUILDER'), findsWidgets);
  });
}
