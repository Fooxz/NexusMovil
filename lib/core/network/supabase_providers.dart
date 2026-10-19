import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

final appEnvProvider = Provider<AppEnv>(
  (ref) => const AppEnv.fromEnvironment(),
);

/// Cliente de Supabase ya inicializado en `main.dart`.
///
/// Solo lo leen los repositorios reales de `data/`. Mientras un feature use su
/// mock, este provider no se lee y la app funciona sin configuración.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  if (!ref.watch(appEnvProvider).hasSupabase) {
    throw StateError(
      'Supabase no está configurado. Ejecuta la app con '
      '--dart-define-from-file=env.json (ver env.example.json).',
    );
  }
  return Supabase.instance.client;
});
