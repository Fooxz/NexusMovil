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
