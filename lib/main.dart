// lib/main.dart
//
// NEXUS — punto de entrada.
// Inicializa Supabase solo si se pasaron SUPABASE_URL y
// SUPABASE_PUBLISHABLE_KEY (ver env.example.json); sin ellos, la app usa los
// repositorios mock. Este archivo también define las rutas.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/env.dart';
import 'routes.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/cart/cart_screen.dart';
import 'features/catalog/presentation/product_detail_screen.dart';
import 'screens/shell/main_shell.dart';
import 'theme/nexus_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const env = AppEnv.fromEnvironment();
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
      initialRoute: NexusRoutes.login,
      routes: {
        NexusRoutes.login: (_) => const LoginScreen(),
        NexusRoutes.signup: (_) => const SignupScreen(),
        NexusRoutes.home: (_) => const MainShell(),
        NexusRoutes.cart: (_) => const CartScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name != NexusRoutes.productDetail) return null;
        final productId = settings.arguments;
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => ProductDetailScreen(
            productId: productId is String ? productId : '',
          ),
        );
      },
    );
  }
}
