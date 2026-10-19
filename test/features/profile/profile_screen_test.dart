import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/features/profile/presentation/profile_screen.dart';

import '../../support/auth_test_support.dart';
import 'mock_profile_repository_test.dart' show address;

void main() {
  late AuthTestBed bed;

  setUp(() => bed = AuthTestBed());

  Future<void> pumpProfile(WidgetTester tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(bed.app(home: const ProfileScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('without a session it invites to sign in', (tester) async {
    await bed.registerAccount();
    await pumpProfile(tester);

    expect(find.text('DATOS PERSONALES'), findsNothing);
    await tapAndSettle(tester, find.text('INICIAR SESIÓN'));
    await enterField(tester, 'tu@correo.com', 'ana@nexus.test');
    await enterField(tester, '••••••••', testPassword);
    await tapAndSettle(tester, find.text('INGRESAR'));

    expect(find.text('DATOS PERSONALES'), findsOneWidget);
    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(find.text('ana@nexus.test'), findsOneWidget);
  });

  testWidgets('edits the personal data with validation', (tester) async {
    await bed.registerAccount(keepSignedIn: true);
    await pumpProfile(tester);

    await tapAndSettle(tester, find.text('EDITAR DATOS'));
    await enterField(tester, '3001234567', '12');
    await tapAndSettle(tester, find.text('GUARDAR'));
    expect(find.text('Escribe un teléfono de 7 a 15 dígitos.'), findsOneWidget);

    await enterField(tester, '3001234567', '300 765 4321');
    await tapAndSettle(tester, find.text('GUARDAR'));

    expect(find.text('DATOS PERSONALES'), findsOneWidget);
    expect(find.text('3007654321'), findsOneWidget);
  });

  testWidgets('adds an address after marking the fields to fix', (tester) async {
    await bed.registerAccount(keepSignedIn: true);
    await pumpProfile(tester);
    expect(find.textContaining('Aún no tienes direcciones'), findsOneWidget);

    await tapAndSettle(tester, find.text('AGREGAR DIRECCIÓN'));
    await tapAndSettle(tester, find.text('GUARDAR DIRECCIÓN'));
    expect(find.text('Completa el nombre.'), findsOneWidget);
    expect(find.text('Elige un departamento.'), findsOneWidget);
    expect(find.text('Escribe un teléfono.'), findsOneWidget);

    await enterField(tester, 'Casa, Oficina…', 'Casa');
    await enterField(tester, 'Nombre completo', 'Ana Pérez');
    await enterField(tester, '3001234567', '3001234567');
    await tapAndSettle(tester, find.text('Elige un departamento'));
    await tapAndSettle(tester, find.text('Antioquia').last);
    await enterField(tester, 'Medellín', 'Medellín');
    await enterField(tester, 'Calle 10 # 20-30', 'Calle 10 # 20-30');
    await tapAndSettle(tester, find.text('GUARDAR DIRECCIÓN'));

    expect(find.text('Casa'), findsOneWidget);
    expect(find.text('PREDETERMINADA'), findsOneWidget);
    expect(find.text('Calle 10 # 20-30, Medellín (Antioquia)'), findsOneWidget);
  });

  testWidgets('changes the default address and deletes after confirming', (
    tester,
  ) async {
    await bed.registerAccount(keepSignedIn: true);
    await bed.profile.createAddress(address('Casa'));
    await bed.profile.createAddress(address('Oficina'));
    await pumpProfile(tester);

    await tapAndSettle(tester, find.text('Usar como predeterminada'));

    // Solo hay una predeterminada y la lista la muestra primero.
    expect(find.text('PREDETERMINADA'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Oficina')).dy,
      lessThan(tester.getTopLeft(find.text('Casa')).dy),
    );

    await tapAndSettle(tester, find.text('Eliminar').first);
    await tapAndSettle(tester, find.widgetWithText(TextButton, 'Eliminar').last);

    expect(await bed.profile.listAddresses(), hasLength(1));
    expect(find.text('PREDETERMINADA'), findsOneWidget);
  });

  testWidgets('signing out returns to the invitation', (tester) async {
    await bed.registerAccount(keepSignedIn: true);
    await pumpProfile(tester);

    await tapAndSettle(tester, find.text('CERRAR SESIÓN'));

    expect(find.text('INICIAR SESIÓN'), findsOneWidget);
    expect(bed.auth.currentUser, isNull);
  });
}
