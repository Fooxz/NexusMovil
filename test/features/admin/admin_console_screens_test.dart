import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/account_test_support.dart';
import '../../support/auth_test_support.dart' show tapAndSettle, usePhoneViewport;

Future<void> _pumpConsole(WidgetTester tester) async {
  usePhoneViewport(tester);
  final bed = RoleTestBed();
  await bed.admin();
  await tester.pumpWidget(bed.app());
  await tester.pumpAndSettle();
}

Future<void> _openSection(WidgetTester tester, String label) async {
  await tapAndSettle(tester, find.byTooltip('Abrir menú'));
  await tapAndSettle(tester, find.descendant(of: find.byType(Drawer), matching: find.text(label)));
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('el resumen muestra lo que necesita atención, las ventas y los gráficos', (tester) async {
    await _pumpConsole(tester);

    expect(find.text('RESUMEN'), findsOneWidget);
    expect(find.text('1 publicación pide revisión'), findsOneWidget);
    expect(find.text('1 pedido con incidencia'), findsOneWidget);
    expect(find.text('1 pedido lleva más de 48 h sin respuesta'), findsOneWidget);
    expect(find.text('Comisión del mes'), findsOneWidget);

    await _scrollTo(tester, find.text('VENTAS DIARIAS'));
    expect(find.textContaining('Últimos 30 días:'), findsOneWidget);
    await tapAndSettle(tester, find.text('Ver tabla'));
    expect(find.text('Ver gráfico'), findsOneWidget, reason: 'los valores también se leen en tabla');
  });

  testWidgets('el menú lista las secciones y marca lo pendiente', (tester) async {
    await _pumpConsole(tester);
    await tapAndSettle(tester, find.byTooltip('Abrir menú'));

    for (final label in ['Resumen', 'Tiendas', 'Moderación del catálogo', 'Pedidos', 'Catálogo general', 'Mi cuenta']) {
      expect(find.descendant(of: find.byType(Drawer), matching: find.text(label)), findsOneWidget);
    }
    expect(find.descendant(of: find.byType(Drawer), matching: find.byType(Badge)), findsWidgets);
  });

  testWidgets('la alerta abre la publicación corregida y el administrador la aprueba', (tester) async {
    await _pumpConsole(tester);
    await tapAndSettle(tester, find.text('1 publicación pide revisión'));

    expect(find.text('MODERACIÓN'), findsOneWidget);
    expect(find.text('1 publicación'), findsOneWidget, reason: 'filtrada por las que piden revisión');
    await tapAndSettle(tester, find.text('Kingston Fury Beast DDR5 32 GB'));

    expect(find.textContaining('Posible duplicado.'), findsOneWidget);
    await _scrollTo(tester, find.text('APROBAR CORRECCIÓN'));
    await tapAndSettle(tester, find.text('APROBAR CORRECCIÓN'));
    expect(find.text('Publicación aprobada.'), findsOneWidget);
    expect(find.text('APROBADA'), findsOneWidget);
  });

  testWidgets('ocultar una publicación exige el motivo para la tienda', (tester) async {
    await _pumpConsole(tester);
    await _openSection(tester, 'Moderación del catálogo');
    await tapAndSettle(tester, find.text('SSD SIN DATOS'));

    expect(find.textContaining('Ficha incompleta.'), findsOneWidget);
    await _scrollTo(tester, find.text('OCULTAR Y PEDIR AJUSTES'));
    await tapAndSettle(tester, find.text('OCULTAR Y PEDIR AJUSTES'));
    await tapAndSettle(tester, find.widgetWithText(TextButton, 'Ocultar'));
    expect(find.text('Escribe al menos 3 caracteres.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'Completa la capacidad y la interfaz');
    await tapAndSettle(tester, find.widgetWithText(TextButton, 'Ocultar'));
    expect(find.text('Publicación oculta: la tienda verá el motivo.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('OCULTA POR NEXUS'), -300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Motivo enviado a la tienda: Completa la capacidad y la interfaz'), findsOneWidget);
  });

  testWidgets('el administrador cancela una sub-orden con incidencia, con observación', (tester) async {
    await _pumpConsole(tester);
    await tapAndSettle(tester, find.text('1 pedido con incidencia'));

    expect(find.text('1 pedido de tienda'), findsOneWidget);
    await tapAndSettle(tester, find.textContaining('TecnoPartes'));
    expect(find.text('PAGO'), findsOneWidget);

    await _scrollTo(tester, find.text('Cancelar pedido'));
    await tapAndSettle(tester, find.text('Cancelar pedido'));
    await tester.enterText(find.byType(TextFormField), 'La tienda no pudo reenviar el producto');
    await tapAndSettle(tester, find.widgetWithText(TextButton, 'Confirmar'));

    expect(find.textContaining('Cancelado.'), findsOneWidget);
    expect(find.textContaining('NEXUS: La tienda no pudo reenviar el producto'), findsOneWidget);
  });
}
