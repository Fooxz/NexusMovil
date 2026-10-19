import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/features/auth/data/mock_auth_repository.dart';

import '../../support/auth_test_support.dart';

void main() {
  late AuthTestBed bed;

  setUp(() => bed = AuthTestBed());

  Future<void> openLogin(WidgetTester tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(bed.guardHost());
    await tapAndSettle(tester, find.text('ACCIÓN PROTEGIDA'));
    expect(find.text('INICIA SESIÓN'), findsOneWidget);
  }

  testWidgets('a protected action opens login with its reason and resumes', (
    tester,
  ) async {
    await bed.registerAccount();
    await openLogin(tester);
    expect(find.text('Inicia sesión para confirmar tu pedido.'), findsOneWidget);

    await enterField(tester, 'tu@correo.com', 'ana@nexus.test');
    await enterField(tester, '••••••••', testPassword);
    await tapAndSettle(tester, find.text('INGRESAR'));

    expect(find.text('INICIA SESIÓN'), findsNothing);
    expect(find.text('resultado: true'), findsOneWidget);
    expect(find.text('sesión: ana@nexus.test'), findsOneWidget);
  });

  testWidgets('wrong credentials show the error and keep the login open', (
    tester,
  ) async {
    await bed.registerAccount();
    await openLogin(tester);

    await enterField(tester, 'tu@correo.com', 'ana@nexus.test');
    await enterField(tester, '••••••••', 'Mala12345');
    await tapAndSettle(tester, find.text('INGRESAR'));

    expect(find.text('El correo o la contraseña no son correctos.'), findsOneWidget);
    expect(find.text('INICIA SESIÓN'), findsOneWidget);
  });

  testWidgets('closing the login reports that there is no session', (tester) async {
    await openLogin(tester);

    await tapAndSettle(tester, find.byTooltip('Cerrar'));

    expect(find.text('resultado: false'), findsOneWidget);
    expect(find.text('sin sesión'), findsOneWidget);
  });

  testWidgets('login validates fields before calling the repository', (
    tester,
  ) async {
    await openLogin(tester);

    await tapAndSettle(tester, find.text('INGRESAR'));

    expect(find.text('Escribe tu correo.'), findsOneWidget);
    expect(find.text('Escribe tu contraseña.'), findsOneWidget);
  });

  group('signup', () {
    Future<void> openSignup(WidgetTester tester) async {
      await openLogin(tester);
      await tapAndSettle(tester, find.text('Crear cuenta'));
      expect(find.text('CREAR CUENTA'), findsWidgets);
    }

    Future<void> fillValidForm(WidgetTester tester) async {
      await enterField(tester, 'Tu nombre completo', 'Beto Ruiz');
      await enterField(tester, 'tu@correo.com', 'beto@nexus.test');
      await enterField(
        tester,
        'Mínimo 8 caracteres, con letras y números',
        testPassword,
      );
      await enterField(tester, 'Repite la contraseña', testPassword);
    }

    testWidgets('requires accepting the documents', (tester) async {
      await openSignup(tester);
      await fillValidForm(tester);

      await tapAndSettle(tester, find.widgetWithText(ElevatedButton, 'CREAR CUENTA'));

      expect(
        find.text('Debes aceptar los documentos para crear tu cuenta.'),
        findsOneWidget,
      );
      expect(bed.auth.currentUser, isNull);
    });

    testWidgets('validates password rules and confirmation', (tester) async {
      await openSignup(tester);
      await enterField(tester, 'Mínimo 8 caracteres, con letras y números', 'corta');
      await enterField(tester, 'Repite la contraseña', 'otra');

      await tapAndSettle(tester, find.widgetWithText(ElevatedButton, 'CREAR CUENTA'));

      expect(find.text('Usa al menos 8 caracteres.'), findsOneWidget);
      expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
    });

    testWidgets('shows the legal text and creates the account', (tester) async {
      await openSignup(tester);
      expect(find.textContaining('He leído y acepto los'), findsOneWidget);

      await fillValidForm(tester);
      await tapAndSettle(tester, find.byType(Checkbox));
      await tapAndSettle(tester, find.widgetWithText(ElevatedButton, 'CREAR CUENTA'));

      expect(find.text('resultado: true'), findsOneWidget);
      expect(find.text('sesión: beto@nexus.test'), findsOneWidget);
    });

    testWidgets('an existing email shows a clear message', (tester) async {
      await bed.registerAccount(email: 'beto@nexus.test');
      await openSignup(tester);
      await fillValidForm(tester);
      await tapAndSettle(tester, find.byType(Checkbox));

      await tapAndSettle(tester, find.widgetWithText(ElevatedButton, 'CREAR CUENTA'));

      expect(find.textContaining('Ya existe una cuenta con ese correo'), findsOneWidget);
    });
  });

  testWidgets('password recovery with the emailed code signs in', (tester) async {
    await bed.registerAccount();
    await openLogin(tester);
    await tapAndSettle(tester, find.text('¿Olvidaste tu contraseña?'));

    await enterField(tester, 'tu@correo.com', 'ana@nexus.test');
    await tapAndSettle(tester, find.text('ENVIAR CÓDIGO'));
    expect(find.textContaining('te llegó un código de 6 dígitos'), findsOneWidget);

    await enterField(tester, '000000', '999999');
    await enterField(tester, 'Mínimo 8 caracteres, con letras y números', 'Nueva12345');
    await enterField(tester, 'Repite la contraseña', 'Nueva12345');
    await tapAndSettle(tester, find.text('CAMBIAR CONTRASEÑA'));
    expect(find.textContaining('El código no es válido'), findsOneWidget);

    await enterField(tester, '000000', MockAuthRepository.recoveryCode);
    await tapAndSettle(tester, find.text('CAMBIAR CONTRASEÑA'));

    expect(find.text('resultado: true'), findsOneWidget);
    await bed.auth.signOut();
    await bed.auth.signIn(email: 'ana@nexus.test', password: 'Nueva12345');
  });
}
