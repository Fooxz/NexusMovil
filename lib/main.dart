// lib/main.dart
//
// NEXUS — punto de entrada.
// Inicializa Supabase solo si se pasaron SUPABASE_URL y
// SUPABASE_PUBLISHABLE_KEY (ver env.example.json); sin ellos, la app usa los
// repositorios mock. Este archivo también define las rutas.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/env.dart';
import 'features/auth/presentation/forgot_password_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/signup_screen.dart';
import 'features/cart/presentation/cart_actions.dart';
import 'features/cart/presentation/cart_screen.dart';
import 'features/checkout/presentation/checkout_screen.dart';
import 'routes.dart';
import 'features/catalog/presentation/product_detail_screen.dart';
import 'screens/shell/main_shell.dart';
import 'theme/nexus_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const env = AppEnv.fromEnvironment();
  final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  for (final warning in env.warnings(isAndroid: isAndroid)) {
    debugPrint('[NEXUS] Configuración: $warning');
  }
  if (env.hasSupabase) {
    await Supabase.initialize(
      url: env.supabaseUrl,
      publishableKey: env.supabasePublishableKey,
    );
  }
  runApp(
    ProviderScope(
      retry: (retryCount, error) => null,
      child: const NexusApp(),
    ),
  );
}

class NexusApp extends StatelessWidget {
  const NexusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NEXUS',
      debugShowCheckedModeBanner: false,
      theme: buildNexusTheme(),
      // El contador del ícono del carrito, para todas las pantallas.
      builder: (context, child) => CartBadgeHost(child: child!),
      // El catálogo se puede recorrer sin cuenta; la sesión se pide al
      // comprar (RN-027) o desde la pestaña PERFIL.
      initialRoute: NexusRoutes.home,
      routes: {
        NexusRoutes.home: (_) => const MainShell(),
      },
      onGenerateRoute: generateNexusRoute,
    );
  }
}

/// Rutas con argumentos o con resultado. Las de cuenta son
/// `MaterialPageRoute<bool>` para que `pushNamed<bool>` reciba si el usuario
/// quedó con sesión (la tabla `routes` crea rutas `<dynamic>` y fallaría).
Route<Object?>? generateNexusRoute(RouteSettings settings) {
  final arguments = settings.arguments;
  return switch (settings.name) {
    NexusRoutes.login => MaterialPageRoute<bool>(
      settings: settings,
      builder: (_) => LoginScreen(reason: arguments is String ? arguments : null),
    ),
    NexusRoutes.signup => MaterialPageRoute<bool>(
      settings: settings,
      builder: (_) => const SignupScreen(),
    ),
    NexusRoutes.forgotPassword => MaterialPageRoute<bool>(
      settings: settings,
      builder: (_) => const ForgotPasswordScreen(),
    ),
    NexusRoutes.cart => MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => const CartScreen(),
    ),
    NexusRoutes.checkout => MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => const CheckoutScreen(),
    ),
    NexusRoutes.productDetail => MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => ProductDetailScreen(
        productId: arguments is String ? arguments : '',
      ),
    ),
    _ => null,
  };
}
