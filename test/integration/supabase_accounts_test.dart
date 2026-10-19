// Prueba de integración de cuentas contra el Supabase local: registro con
// consentimiento, perfil, direcciones con RLS y recuperación por código
// (lee el correo en Mailpit, http://127.0.0.1:54324). Se salta sin
// configuración; ver supabase_catalog_test.dart para ejecutarla.
@Tags(['integration'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/core/config/env.dart';
import 'package:prueba01/core/errors/app_failure.dart';
import 'package:prueba01/features/auth/data/supabase_auth_repository.dart';
import 'package:prueba01/features/auth/domain/auth_models.dart';
import 'package:prueba01/features/profile/data/supabase_profile_repository.dart';
import 'package:prueba01/features/profile/domain/profile_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

const _password = 'Nexus12345';

void main() {
  const env = AppEnv.fromEnvironment();
  final skip = env.hasSupabase
      ? false
      : 'Sin SUPABASE_URL/SUPABASE_PUBLISHABLE_KEY (ver env.example.json)';

  // Un cliente por usuario, como dos dispositivos distintos. Flujo implícito:
  // el PKCE necesita almacenamiento, que en la app pone Supabase.initialize.
  SupabaseClient newClient() => SupabaseClient(
    env.supabaseUrl,
    env.supabasePublishableKey,
    authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
  );

  final runId = DateTime.now().millisecondsSinceEpoch;
  final emailA = 'ana.$runId@nexus.test';
  final emailB = 'beto.$runId@nexus.test';

  late SupabaseAuthRepository authA;
  late SupabaseProfileRepository profileA;
  late List<LegalDocument> documents;

  setUpAll(() async {
    if (!env.hasSupabase) return;
    final client = newClient();
    authA = SupabaseAuthRepository(client);
    profileA = SupabaseProfileRepository(client);
    documents = await authA.getCurrentLegalDocuments();
  });

  AddressInput address(String label, {bool isDefault = false}) => AddressInput(
    label: label,
    recipientName: 'Ana Pérez',
    phone: '300 123 4567',
    department: 'Antioquia',
    city: 'Medellín',
    addressLine: 'Calle 10 # 20-30',
    isDefault: isDefault,
  );

  test('signup requires the current documents and unique emails', () async {
    expect(documents.map((d) => d.code), containsAll(['terms', 'privacy']));

    await expectLater(
      authA.signUp(
        fullName: 'Ana Pérez',
        email: emailA,
        password: _password,
        acceptedDocuments: const [],
      ),
      throwsA(isA<ConsentRequiredFailure>()),
    );
    await expectLater(
      authA.signUp(
        fullName: 'Ana Pérez',
        email: emailA,
        password: 'corta1',
        acceptedDocuments: documents,
      ),
      throwsA(isA<WeakPasswordFailure>()),
    );

    final result = await authA.signUp(
      fullName: 'Ana Pérez',
      email: emailA,
      password: _password,
      acceptedDocuments: documents,
    );
    expect(result, SignUpResult.signedIn);
    expect(authA.currentUser?.email, emailA);

    await expectLater(
      SupabaseAuthRepository(newClient()).signUp(
        fullName: 'Otra Ana',
        email: emailA,
        password: _password,
        acceptedDocuments: documents,
      ),
      throwsA(isA<EmailAlreadyRegisteredFailure>()),
    );
  }, skip: skip);

  test('profile comes from signup and the backend validates it', () async {
    expect((await profileA.getProfile()).fullName, 'Ana Pérez');

    final updated = await profileA.updateProfile(
      fullName: 'Ana María Pérez',
      phone: '300 123-4567',
    );
    expect(updated.phone, '3001234567');

    await expectLater(
      profileA.updateProfile(fullName: 'Ana', phone: '12ab'),
      throwsA(isA<ValidationFailure>()),
    );
  }, skip: skip);

  test('addresses keep one default and stay private to their owner', () async {
    await profileA.createAddress(address('Casa'));
    await profileA.createAddress(address('Oficina', isDefault: true));
    var addresses = await profileA.listAddresses();
    expect(addresses.map((a) => '${a.label}${a.isDefault ? '*' : ''}'), [
      'Oficina*',
      'Casa',
    ]);

    await profileA.deleteAddress(addresses.first.id);
    addresses = await profileA.listAddresses();
    expect(addresses.single.label, 'Casa');
    expect(addresses.single.isDefault, isTrue);

    // Otro usuario no ve ni puede borrar las direcciones de Ana.
    final clientB = newClient();
    await SupabaseAuthRepository(clientB).signUp(
      fullName: 'Beto Ruiz',
      email: emailB,
      password: _password,
      acceptedDocuments: documents,
    );
    final profileB = SupabaseProfileRepository(clientB);
    expect(await profileB.listAddresses(), isEmpty);
    await profileB.deleteAddress(addresses.single.id);
    expect(await profileA.listAddresses(), hasLength(1));
  }, skip: skip);

  test('sign in, sign out and wrong credentials', () async {
    await authA.signOut();
    expect(authA.currentUser, isNull);
    await expectLater(
      profileA.listAddresses(),
      throwsA(isA<UnauthorizedFailure>()),
    );

    await expectLater(
      authA.signIn(email: emailA, password: 'Mala12345'),
      throwsA(isA<InvalidCredentialsFailure>()),
    );
    await authA.signIn(email: emailA, password: _password);
    expect(authA.currentUser?.email, emailA);
  }, skip: skip);

  test('password recovery with the emailed 6-digit code (PKCE, as the app)', () async {
    // La app usa PKCE (predeterminado de Supabase.initialize): la solicitud
    // de recuperación lleva un code_challenge. El código de 6 dígitos debe
    // funcionar igual.
    final auth = SupabaseAuthRepository(
      SupabaseClient(
        env.supabaseUrl,
        env.supabasePublishableKey,
        authOptions: AuthClientOptions(pkceAsyncStorage: _MemoryStorage()),
      ),
    );
    await auth.requestPasswordReset(emailA);

    final code = await _latestRecoveryCode(emailA);
    await expectLater(
      auth.resetPassword(email: emailA, code: '000000', newPassword: 'Nueva12345'),
      throwsA(isA<InvalidCodeFailure>()),
    );
    await auth.resetPassword(email: emailA, code: code, newPassword: 'Nueva12345');
    expect(auth.currentUser?.email, emailA);

    final fresh = SupabaseAuthRepository(newClient());
    await fresh.signIn(email: emailA, password: 'Nueva12345');
    expect(fresh.currentUser?.email, emailA);
  }, skip: skip);
}

/// Busca en Mailpit el último correo de recuperación enviado a [email].
Future<String> _latestRecoveryCode(String email) async {
  final client = HttpClient();
  try {
    Future<Map<String, Object?>> getJson(String url) async {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      return jsonDecode(await response.transform(utf8.decoder).join())
          as Map<String, Object?>;
    }

    for (var attempt = 0; attempt < 20; attempt++) {
      final search = await getJson(
        'http://127.0.0.1:54324/api/v1/search?query=${Uri.encodeQueryComponent('to:$email')}',
      );
      final messages = search['messages'] as List<Object?>? ?? const [];
      if (messages.isNotEmpty) {
        final id = (messages.first as Map<String, Object?>)['ID'];
        final message = await getJson('http://127.0.0.1:54324/api/v1/message/$id');
        final body = '${message['Text']} ${message['HTML']}';
        final code = RegExp(r'\b\d{6}\b').firstMatch(body)?.group(0);
        if (code != null) return code;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    throw StateError('No llegó el correo de recuperación a $email');
  } finally {
    client.close();
  }
}

class _MemoryStorage extends GotrueAsyncStorage {
  final _items = <String, String>{};

  @override
  Future<String?> getItem({required String key}) async => _items[key];

  @override
  Future<void> setItem({required String key, required String value}) async =>
      _items[key] = value;

  @override
  Future<void> removeItem({required String key}) async => _items.remove(key);
}
