import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/features/auth/auth_providers.dart';
import 'package:prueba01/features/auth/data/mock_auth_repository.dart';
import 'package:prueba01/features/auth/presentation/auth_guard.dart';
import 'package:prueba01/features/profile/data/mock_profile_repository.dart';
import 'package:prueba01/features/profile/profile_providers.dart';
import 'package:prueba01/main.dart';

const testPassword = 'Nexus12345';

/// Repositorios en memoria sin latencia, compartidos por auth y perfil.
class AuthTestBed {
  AuthTestBed() : auth = MockAuthRepository(latency: Duration.zero) {
    profile = MockProfileRepository(auth, latency: Duration.zero);
  }

  final MockAuthRepository auth;
  late final MockProfileRepository profile;

  List<Override> get overrides => [
    authRepositoryProvider.overrideWithValue(auth),
    profileRepositoryProvider.overrideWithValue(profile),
  ];

  /// Crea una cuenta y deja la sesión cerrada.
  Future<void> registerAccount({
    String email = 'ana@nexus.test',
    String fullName = 'Ana Pérez',
    String password = testPassword,
    bool keepSignedIn = false,
  }) async {
    await auth.signUp(
      fullName: fullName,
      email: email,
      password: password,
      acceptedDocuments: MockAuthRepository.documents,
    );
    if (!keepSignedIn) await auth.signOut();
  }

  /// Pantalla con un botón que pide sesión y muestra el resultado.
  Widget guardHost() => ProviderScope(
    overrides: overrides,
    retry: (retryCount, error) => null,
    child: MaterialApp(
      onGenerateRoute: generateNexusRoute,
      home: Consumer(
        builder: (context, ref, _) {
          final user = ref.watch(currentUserProvider);
          return Scaffold(
            body: Column(
              children: [
                Text(user == null ? 'sin sesión' : 'sesión: ${user.email}'),
                ElevatedButton(
                  onPressed: () async {
                    final ok = await ensureSignedIn(
                      context,
                      ref,
                      reason: 'para confirmar tu pedido',
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('resultado: $ok')));
                    }
                  },
                  child: const Text('ACCIÓN PROTEGIDA'),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );

  Widget app({required Widget home}) => ProviderScope(
    overrides: overrides,
    retry: (retryCount, error) => null,
    child: MaterialApp(onGenerateRoute: generateNexusRoute, home: home),
  );
}

/// Escribe en el campo cuyo hint es [hint].
Future<void> enterField(WidgetTester tester, String hint, String text) =>
    tester.enterText(
      find.widgetWithText(TextFormField, hint).first,
      text,
    );

/// Las pantallas de cuenta son altas: un teléfono de 412 x 915 evita que los
/// botones queden fuera de la vista en las pruebas.
void usePhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
