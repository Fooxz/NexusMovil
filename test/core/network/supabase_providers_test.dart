import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prueba01/core/config/env.dart';
import 'package:prueba01/core/network/supabase_providers.dart';

void main() {
  test('AppEnv requires both URL and publishable key', () {
    expect(const AppEnv().hasSupabase, isFalse);
    expect(const AppEnv(supabaseUrl: 'http://x').hasSupabase, isFalse);
    expect(
      const AppEnv(
        supabaseUrl: 'http://x',
        supabasePublishableKey: 'sb_publishable_x',
      ).hasSupabase,
      isTrue,
    );
  });

  test('warns about the example key and the emulator host outside Android', () {
    const exampleOnWeb = AppEnv(
      supabaseUrl: 'http://10.0.2.2:54321',
      supabasePublishableKey: 'sb_publishable_reemplazar_con_la_de_supabase_status',
    );
    const realOnAndroid = AppEnv(
      supabaseUrl: 'http://10.0.2.2:54321',
      supabasePublishableKey: 'sb_publishable_abc',
    );

    expect(exampleOnWeb.warnings(isAndroid: false), hasLength(2));
    expect(exampleOnWeb.warnings(isAndroid: true), hasLength(1));
    expect(realOnAndroid.warnings(isAndroid: true), isEmpty);
  });

  test('never uses a server key in the app', () {
    String jwt(Map<String, Object?> payload) =>
        'eyJhbGciOiJIUzI1NiJ9.${base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '')}.firma';
    const url = 'https://abc.supabase.co';

    for (final key in [
      'sb_secret_N7UND0UgjKTVK',
      jwt({'role': 'service_role'}),
    ]) {
      final env = AppEnv(supabaseUrl: url, supabasePublishableKey: key);
      expect(env.usesServerKey, isTrue, reason: key);
      expect(env.hasSupabase, isFalse, reason: 'no se inicia Supabase');
      expect(env.warnings(isAndroid: true).single, contains('clave de servidor'));
    }
    for (final key in ['sb_publishable_abc', jwt({'role': 'anon'})]) {
      final env = AppEnv(supabaseUrl: url, supabasePublishableKey: key);
      expect(env.usesServerKey, isFalse, reason: key);
      expect(env.hasSupabase, isTrue);
    }
  });

  test('tests run without Supabase configured', () {
    expect(const AppEnv.fromEnvironment().hasSupabase, isFalse);
  });

  test('supabaseClientProvider fails clearly when not configured', () {
    final container = ProviderContainer(
      overrides: [appEnvProvider.overrideWithValue(const AppEnv())],
    );
    addTearDown(container.dispose);

    expect(
      () => container.read(supabaseClientProvider),
      throwsA(
        predicate((error) => error.toString().contains('env.example.json')),
      ),
    );
  });
}
