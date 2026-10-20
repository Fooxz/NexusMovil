import 'package:prueba01/core/config/env.dart';

/// Motivo para saltar las pruebas de integración, o `false` para correrlas.
///
/// Solo corren contra el Supabase **local**: crean cuentas, carritos y
/// direcciones de prueba que no deben quedar en la nube. Para correrlas a
/// propósito contra otro proyecto: `--dart-define=ALLOW_REMOTE_INTEGRATION=true`.
Object integrationSkip(AppEnv env) {
  if (!env.hasSupabase) {
    return 'Sin SUPABASE_URL/SUPABASE_PUBLISHABLE_KEY (ver env.example.json)';
  }
  const allowRemote = bool.fromEnvironment('ALLOW_REMOTE_INTEGRATION');
  final host = Uri.tryParse(env.supabaseUrl)?.host ?? '';
  const localHosts = {'127.0.0.1', 'localhost', '10.0.2.2'};
  if (!localHosts.contains(host) && !allowRemote) {
    return 'SUPABASE_URL no es local ($host): las pruebas crean datos de prueba. '
        'Usa ALLOW_REMOTE_INTEGRATION=true si es a propósito.';
  }
  return false;
}
