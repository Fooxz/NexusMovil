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

  /// Errores de configuración frecuentes, para avisar al arrancar en debug.
  /// [isAndroid] indica si la app corre en Android (emulador o teléfono).
  List<String> warnings({required bool isAndroid}) => [
    if (supabasePublishableKey.contains('reemplazar'))
      'SUPABASE_PUBLISHABLE_KEY es la de ejemplo: copia la "Publishable key" '
          'de `npx supabase status` (en backend/).',
    if (!isAndroid && supabaseUrl.contains('10.0.2.2'))
      'SUPABASE_URL usa 10.0.2.2, que solo existe en el emulador de Android. '
          'En Chrome o Windows usa http://127.0.0.1:54321 (env.json).',
  ];
}
