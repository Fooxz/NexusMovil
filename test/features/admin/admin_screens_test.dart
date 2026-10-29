import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/account_test_support.dart';
import '../../support/auth_test_support.dart' show enterField, tapAndSettle, usePhoneViewport;

/// Abre una sección de la consola desde el menú lateral.
Future<void> _openSection(WidgetTester tester, String label) async {
  await tapAndSettle(tester, find.byTooltip('Abrir menú'));
  await tapAndSettle(tester, find.descendant(of: find.byType(Drawer), matching: find.text(label)));
}

/// La consola abre en el resumen; estas pruebas empiezan en Tiendas.
Future<RoleTestBed> _pumpAdmin(WidgetTester tester) async {
  usePhoneViewport(tester);
  final bed = RoleTestBed();
  await bed.admin();
  await tester.pumpWidget(bed.app());
  await tester.pumpAndSettle();
  await _openSection(tester, 'Tiendas');
  return bed;
}

Future<void> _fillStore(WidgetTester tester, {String displayName = 'Tienda Nueva', String taxId = '900555777-1'}) async {
  await enterField(tester, 'Ej. Mundo PC Colombia S.A.S.', '$displayName S.A.S.');
  await enterField(tester, 'Ej. Mundo PC', displayName);
  await enterField(tester, 'Ej. 900123456-7', taxId);
  await enterField(tester, 'ventas@tienda.com', 'ventas@nueva.co');
  await tester.ensureVisible(find.widgetWithText(TextFormField, 'dueno@tienda.com'));
  await enterField(tester, 'dueno@tienda.com', 'dueno@nueva.co');
  await enterField(tester, 'Nombre completo', 'Laura Gómez');
}

String _shownPassword(WidgetTester tester) =>
    tester.widget<SelectableText>(find.byType(SelectableText)).data!;

void main() {
  testWidgets('el administrador ve las tiendas, incluso las que no tienen cuenta', (tester) async {
    await _pumpAdmin(tester);
    expect(find.text('TecnoPartes'), findsOneWidget);
    expect(find.text('Mundo PC'), findsOneWidget);
    expect(find.text('Sin cuenta'), findsNWidgets(3));
  });

  testWidgets('crea una tienda y la contraseña temporal se muestra una sola vez', (tester) async {
    await _pumpAdmin(tester);
    await tapAndSettle(tester, find.text('CREAR TIENDA'));
    await _fillStore(tester);
    await tapAndSettle(tester, find.text('CREAR TIENDA Y CUENTA'));

    expect(find.text('Contraseña temporal'), findsOneWidget);
    expect(_shownPassword(tester), hasLength(20));
    expect(find.textContaining('NEXUS no la guarda'), findsOneWidget);

    await tapAndSettle(tester, find.text('Listo'));
    expect(find.text('Tienda Nueva'), findsOneWidget);
    expect(find.text('dueno@nueva.co'), findsOneWidget);
    expect(find.byType(SelectableText), findsNothing, reason: 'no queda visible después de cerrar');
  });

  testWidgets('un nombre visible parecido se confirma antes de crear', (tester) async {
    await _pumpAdmin(tester);
    await tapAndSettle(tester, find.text('CREAR TIENDA'));
    await _fillStore(tester, displayName: 'mundo pc');
    await tapAndSettle(tester, find.text('CREAR TIENDA Y CUENTA'));

    expect(find.text('Nombre parecido'), findsOneWidget);
    await tapAndSettle(tester, find.text('Es otro negocio'));
    expect(find.text('Contraseña temporal'), findsOneWidget);
  });

  testWidgets('suspende con motivo y vuelve a habilitar una tienda', (tester) async {
    await _pumpAdmin(tester);
    await tapAndSettle(tester, find.text('TecnoPartes'));
    await tapAndSettle(tester, find.text('CAMBIAR ESTADO'));
    await tapAndSettle(tester, find.text('Suspender'));
    // Sin motivo no se suspende.
    await tapAndSettle(tester, find.widgetWithText(TextButton, 'Suspender'));
    expect(find.text('Escribe al menos 3 caracteres.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Documentos vencidos');
    await tapAndSettle(tester, find.widgetWithText(TextButton, 'Suspender'));

    expect(find.text('Suspendida'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Documentos vencidos'), 300);
    expect(find.text('Habilitada → Suspendida'), findsOneWidget, reason: 'queda en el historial');

    await tester.scrollUntilVisible(find.text('CAMBIAR ESTADO'), -300);
    await tapAndSettle(tester, find.text('CAMBIAR ESTADO'));
    await tapAndSettle(tester, find.text('Habilitar'));
    await tapAndSettle(tester, find.widgetWithText(TextButton, 'Habilitar'));
    expect(find.text('Habilitada'), findsOneWidget);
  });

  testWidgets('crea la cuenta de una tienda que ya existía', (tester) async {
    await _pumpAdmin(tester);
    await tapAndSettle(tester, find.text('Mundo PC'));
    await tapAndSettle(tester, find.text('CREAR CUENTA PARA LA TIENDA'));
    await enterField(tester, 'dueno@tienda.com', 'admin@mundopc.co');
    await enterField(tester, 'Nombre completo', 'Carlos Ruiz');
    // El título de la página también dice CREAR CUENTA.
    await tapAndSettle(tester, find.widgetWithText(ElevatedButton, 'CREAR CUENTA'));

    expect(find.text('Contraseña temporal'), findsOneWidget);
    await tapAndSettle(tester, find.text('Listo'));
    expect(find.text('admin@mundopc.co'), findsOneWidget);
    expect(find.text('REGENERAR CONTRASEÑA TEMPORAL'), findsOneWidget);
  });

  testWidgets('la tienda creada entra con la contraseña temporal y pasa a su primer ingreso', (tester) async {
    final bed = await _pumpAdmin(tester);
    await tapAndSettle(tester, find.text('CREAR TIENDA'));
    await _fillStore(tester);
    await tapAndSettle(tester, find.text('CREAR TIENDA Y CUENTA'));
    final password = _shownPassword(tester);
    await tapAndSettle(tester, find.text('Listo'));

    await _openSection(tester, 'Mi cuenta');
    await tapAndSettle(tester, find.text('CERRAR SESIÓN'));
    await bed.auth.signIn(email: 'dueno@nueva.co', password: password);
    await tester.pumpAndSettle();

    expect(find.text('ACTIVA TU TIENDA'), findsOneWidget);
    expect(find.textContaining('Tienda Nueva'), findsOneWidget);
  });
}
