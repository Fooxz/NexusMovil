// lib/main.dart
//
// NEXUS — mockups navegables.
// Todas las pantallas son visuales; no hay conexión a base de datos ni
// autenticación real todavía. Este archivo solo define las rutas para
// poder recorrer el prototipo de punta a punta.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'routes.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/cart/cart_screen.dart';
import 'features/catalog/presentation/product_detail_screen.dart';
import 'screens/shell/main_shell.dart';
import 'theme/nexus_theme.dart';

void main() => runApp(const ProviderScope(child: NexusApp()));

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
        NexusRoutes.productDetail: (_) => const ProductDetailScreen(),
        NexusRoutes.cart: (_) => const CartScreen(),
      },
    );
  }
}
