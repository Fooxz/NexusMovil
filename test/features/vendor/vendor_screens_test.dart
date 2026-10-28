import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/features/vendor/data/mock_vendor_repository.dart';
import 'package:prueba01/features/vendor/presentation/vendor_shell.dart';
import 'package:prueba01/features/vendor/vendor_providers.dart';

import '../../support/auth_test_support.dart' show tapAndSettle, usePhoneViewport;

void main() {
  late MockVendorRepository repository;

  setUp(() => repository = MockVendorRepository(clock: () => DateTime(2026, 10, 28, 15)));

  Future<void> pumpPanel(WidgetTester tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [vendorRepositoryProvider.overrideWithValue(repository)],
        retry: (retryCount, error) => null,
        child: const MaterialApp(home: VendorShell()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSection(WidgetTester tester, String label) async {
    await tapAndSettle(tester, find.byTooltip('Abrir menú'));
    await tapAndSettle(tester, find.descendant(of: find.byType(Drawer), matching: find.text(label)));
  }

  testWidgets('opens on the summary with alerts, sales and the money of the month', (tester) async {
    await pumpPanel(tester);

    expect(find.text('RESUMEN'), findsOneWidget);
    expect(find.text('1 pedido nuevo por aceptar'), findsOneWidget);
    expect(find.text('1 producto publicado está agotado'), findsOneWidget);
    expect(find.text('1 producto con stock bajo'), findsOneWidget);
    // Hoy: 1 × $2.899.900; neto con la comisión del 10 % sobre la base sin IVA.
    expect(find.text('\$2.899.900'), findsWidgets);
    expect(find.text('Ganancia neta'), findsOneWidget);
  });

  testWidgets('the menu lists the sections and marks the new orders', (tester) async {
    await pumpPanel(tester);
    await tapAndSettle(tester, find.byTooltip('Abrir menú'));

    for (final label in ['Resumen', 'Productos', 'Inventario', 'Pedidos', 'Catálogo general', 'Mi cuenta']) {
      expect(find.descendant(of: find.byType(Drawer), matching: find.text(label)), findsOneWidget);
    }
    expect(find.descendant(of: find.byType(Badge), matching: find.text('1')), findsOneWidget);
  });

  testWidgets('a new order is accepted, prepared and shipped with its tracking number', (tester) async {
    await pumpPanel(tester);
    await tapAndSettle(tester, find.text('1 pedido nuevo por aceptar'));
    expect(find.text('PEDIDOS'), findsOneWidget);

    await tapAndSettle(tester, find.text('Pedido NX-000101'));
    expect(find.text('ACEPTAR PEDIDO'), findsOneWidget);
    expect(find.text('Rechazar pedido'), findsOneWidget);
    expect(find.text('CC 1065000000'), findsOneWidget, reason: 'documento para facturar');

    await tapAndSettle(tester, find.text('ACEPTAR PEDIDO'));
    await tapAndSettle(tester, find.text('EMPEZAR A PREPARAR'));
    await tapAndSettle(tester, find.text('MARCAR COMO ENVIADO'));

    // Sin guía no se envía.
    await tapAndSettle(tester, find.widgetWithText(TextButton, 'Marcar como enviado'));
    expect(find.text('Escribe la transportadora.'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Transportadora'), 'Servientrega');
    await tester.enterText(find.widgetWithText(TextFormField, 'Número de guía'), 'SV-12345');
    await tapAndSettle(tester, find.widgetWithText(TextButton, 'Marcar como enviado'));

    expect(find.text('ENVIADO'), findsOneWidget);
    expect(find.text('SV-12345'), findsOneWidget);
    expect(find.text('MARCAR COMO ENTREGADO'), findsOneWidget);
  });

  testWidgets('rejecting asks for the reason', (tester) async {
    await pumpPanel(tester);
    await tapAndSettle(tester, find.text('1 pedido nuevo por aceptar'));
    await tapAndSettle(tester, find.text('Pedido NX-000101'));

    await tapAndSettle(tester, find.text('Rechazar pedido'));
    expect(find.textContaining('Las unidades vuelven a tu stock'), findsOneWidget);
    await tapAndSettle(tester, find.text('Confirmar'));
    expect(find.text('Escribe el motivo (al menos 3 caracteres).'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'Sin unidades en bodega');
    await tapAndSettle(tester, find.text('Confirmar'));
    expect(find.text('RECHAZADO'), findsOneWidget);
    expect(find.text('Motivo: Sin unidades en bodega'), findsOneWidget);
  });

  testWidgets('the inventory registers an entry with its reason and shows it in the history', (tester) async {
    await pumpPanel(tester);
    await openSection(tester, 'Inventario');

    expect(find.text('INVENTARIO'), findsOneWidget);
    expect(find.text('Stock bajo (1)'), findsOneWidget);
    expect(find.text('Agotados (1)'), findsOneWidget);

    await tapAndSettle(tester, find.text('Agotados (1)'));
    expect(find.text('SAMSUNG 990 EVO PLUS 1TB'), findsOneWidget);
    expect(find.text('KINGSTON FURY BEAST DDR5 32GB'), findsNothing);

    await tapAndSettle(tester, find.text('MOVER STOCK'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Unidades'), '6');
    await tester.pump();
    expect(find.text('El stock quedará en 6'), findsOneWidget);
    await tapAndSettle(tester, find.text('REGISTRAR MOVIMIENTO'));
    expect(find.text('Escribe el motivo.'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Llegó mercancía del distribuidor'), 'Pedido al mayorista');
    await tapAndSettle(tester, find.text('REGISTRAR MOVIMIENTO'));

    expect(find.text('No hay productos con ese filtro.'), findsOneWidget, reason: 'ya no está agotado');
    await tapAndSettle(tester, find.text('Todos (3)'));
    await tapAndSettle(tester, find.byTooltip('Historial').first);
    expect(find.text('MOVIMIENTOS'), findsOneWidget);
  });
}
