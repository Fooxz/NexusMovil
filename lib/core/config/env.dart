/// Configuración de entorno inyectada al compilar con `--dart-define` o
/// `--dart-define-from-file=env.json` (ver `env.example.json`).
///
/// Sin valores, la app arranca sin Supabase y sigue usando los repositorios
/// mock. Así las pruebas y `flutter run` sin configuración siguen funcionando.
class AppEnv {
  const AppEnv({this.supabaseUrl = '', this.supabasePublishableKey = ''});

  const AppEnv.fromEnvironment()
    : supabaseUrl = const String.fromEnvironment('SUPABASE_URL'),
      supabasePublishableKey = const String.fromEnvironment(
        'SUPABASE_PUBLISHABLE_KEY',
      );

  final String supabaseUrl;

  /// Clave publicable del proyecto: es pública por diseño y la protege RLS.
  /// Nunca poner aquí la clave `service_role` ni secretos de servidor.
  final String supabasePublishableKey;

  bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}
