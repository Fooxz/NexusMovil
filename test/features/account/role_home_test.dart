import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/features/account/account_providers.dart';
import 'package:prueba01/features/account/domain/account_models.dart';
import 'package:prueba01/features/cart/cart_providers.dart';
import 'package:prueba01/features/cart/domain/cart_models.dart';
import 'package:prueba01/features/cart/domain/cart_repository.dart';

import '../../support/account_test_support.dart';
import '../../support/auth_test_support.dart' show enterField, tapAndSettle, usePhoneViewport;

/// Falla si alguien pide el carrito guardado.
class _NoSavedCartRepository implements CartRepository {
  var loads = 0;

  @override
  Future<List<CartItem>> load() async {
    loads++;
    throw StateError('no debe consultar el carrito');
  }

  @override
  Future<List<CartItem>> preview(List<CartEntry> entries) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Etiqueta de la barra inferior (el contenido puede repetir el texto).
Finder navLabel(String text) =>
    find.descendant(of: find.byType(BottomNavigationBar), matching: find.text(text));

void main() {
  group('pantalla inicial según el rol', () {
    testWidgets('sin sesión abre el shell del cliente', (tester) async {
      final bed = RoleTestBed();
      await tester.pumpWidget(bed.app());
      await tester.pumpAndSettle();

      expect(navLabel('INICIO'), findsOneWidget);
      expect(navLabel('PC BUILDER'), findsOneWidget);
      expect(navLabel('PUBLICACIONES'), findsNothing);
    });

    testWidgets('un cliente con sesión sigue en el shell del cliente', (tester) async {
      final bed = RoleTestBed();
      await bed.customer();
      await tester.pumpWidget(bed.app());
      await tester.pumpAndSettle();

      expect(navLabel('ASISTENTE'), findsOneWidget);
      expect(find.byIcon(Icons.shopping_cart_outlined), findsWidgets);
    });

    testWidgets('una tienda abre su shell, sin carrito ni herramientas de compra', (tester) async {
      final bed = RoleTestBed();
      await bed.store();
      await tester.pumpWidget(bed.app());
      await tester.pumpAndSettle();

      expect(navLabel('PUBLICACIONES'), findsOneWidget);
      expect(navLabel('ASISTENTE'), findsNothing);
      expect(navLabel('PC BUILDER'), findsNothing);

      await tapAndSettle(tester, find.text('CATÁLOGO'));
      expect(find.text('CATÁLOGO COMPLETO'), findsOneWidget);
      expect(find.byIcon(Icons.shopping_cart_outlined), findsNothing);
    });

    testWidgets('un administrador abre su shell', (tester) async {
      final bed = RoleTestBed();
      await bed.admin();
      await tester.pumpWidget(bed.app());
      await tester.pumpAndSettle();

      expect(navLabel('TIENDAS'), findsOneWidget);
      expect(navLabel('PC BUILDER'), findsNothing);
      await tapAndSettle(tester, find.text('CUENTA'));
      expect(find.text('Administrador de NEXUS'), findsOneWidget);
    });

    testWidgets('el primer ingreso de una tienda pide contraseña y documentos', (tester) async {
      usePhoneViewport(tester);
      final bed = RoleTestBed();
      await bed.store(provisioned: true);
      await tester.pumpWidget(bed.app());
      await tester.pumpAndSettle();

      expect(find.text('ACTIVA TU TIENDA'), findsOneWidget);
      expect(find.textContaining('Paso 1 de 2'), findsOneWidget);
      expect(navLabel('PUBLICACIONES'), findsNothing);

      await enterField(tester, 'Mínimo 8 caracteres, con letras y números', 'Definitiva2026');
      await enterField(tester, 'Repite la contraseña', 'Definitiva2026');
      await tapAndSettle(tester, find.text('GUARDAR Y CONTINUAR'));
      expect(find.textContaining('Paso 2 de 2'), findsOneWidget);

      await tapAndSettle(tester, find.text('ACEPTAR Y CONTINUAR'));
      expect(find.text('Debes aceptar los documentos para publicar en NEXUS.'), findsOneWidget);

      await tapAndSettle(tester, find.byType(Checkbox));
      await tapAndSettle(tester, find.text('ACEPTAR Y CONTINUAR'));
      expect(navLabel('PUBLICACIONES'), findsOneWidget);
    });

    testWidgets('un cliente que inicia sesión conserva la pestaña en la que estaba', (tester) async {
      final bed = RoleTestBed();
      await bed.customer(signedIn: false);
      await tester.pumpWidget(bed.app());
      await tester.pumpAndSettle();
      await tapAndSettle(tester, find.text('PERFIL'));
      expect(find.text('INICIAR SESIÓN'), findsOneWidget);

      await bed.auth.signIn(email: 'cliente@nexus.test', password: rolePassword);
      await tester.pumpAndSettle();

      expect(find.text('CERRAR SESIÓN'), findsOneWidget, reason: 'sigue en PERFIL, ya con sesión');
      expect(find.text('TIENDA DE\nTECNOLOGÍA'), findsNothing, reason: 'no volvió a INICIO');
    });

    testWidgets('una tienda que cierra sesión vuelve al shell del cliente', (tester) async {
      final bed = RoleTestBed();
      await bed.store();
      await tester.pumpWidget(bed.app());
      await tester.pumpAndSettle();
      await tapAndSettle(tester, find.text('CUENTA'));
      await tapAndSettle(tester, find.text('CERRAR SESIÓN'));

      expect(navLabel('INICIO'), findsOneWidget);
      expect(navLabel('PUBLICACIONES'), findsNothing);
    });
  });

  group('carrito según el rol', () {
    Future<(CartState, int)> cartFor(Future<String> Function(RoleTestBed) signIn) async {
      final bed = RoleTestBed();
      await signIn(bed);
      final carts = _NoSavedCartRepository();
      final container = ProviderContainer(
        overrides: [...bed.overrides, cartRepositoryProvider.overrideWithValue(carts)],
        retry: (retryCount, error) => null,
      );
      addTearDown(container.dispose);
      final state = await container.read(cartControllerProvider.future);
      return (state, carts.loads);
    }

    test('una tienda no consulta el carrito guardado', () async {
      final (state, loads) = await cartFor((bed) => bed.store());
      expect(state.items, isEmpty);
      expect(loads, 0);
    });

    test('un administrador tampoco', () async {
      final (state, loads) = await cartFor((bed) => bed.admin());
      expect(state.items, isEmpty);
      expect(loads, 0);
    });

    test('un cliente sí lo consulta', () async {
      final bed = RoleTestBed();
      await bed.customer();
      final carts = _NoSavedCartRepository();
      final container = ProviderContainer(
        overrides: [...bed.overrides, cartRepositoryProvider.overrideWithValue(carts)],
        retry: (retryCount, error) => null,
      );
      addTearDown(container.dispose);
      await expectLater(container.read(cartControllerProvider.future), throwsStateError);
      expect(carts.loads, 1);
    });

    test('canBuyProvider sigue el rol de la cuenta', () async {
      final bed = RoleTestBed();
      await bed.store();
      final container = ProviderContainer(overrides: bed.overrides);
      addTearDown(container.dispose);
      await container.read(accountProvider.future);
      expect(container.read(canBuyProvider), isFalse);
      expect(container.read(accountProvider).value?.role, AccountRole.provider);
    });
  });
}
