// lib/main.dart
//
// NEXUS — mockups navegables.
// Todas las pantallas son visuales; no hay conexión a base de datos ni
// autenticación real todavía. Este archivo solo define las rutas para
// poder recorrer el prototipo de punta a punta.

import 'package:flutter/material.dart';

import 'routes.dart';
import 'theme/nexus_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/catalog/catalog_screen.dart';
import 'screens/catalog/product_detail_screen.dart';
import 'screens/cart/cart_screen.dart';
import 'screens/comparator/comparator_screen.dart';
import 'screens/pc_builder/pc_builder_screen.dart';

void main() => runApp(const NexusApp());

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
        NexusRoutes.home: (_) => const HomeScreen(),
        NexusRoutes.catalog: (_) => const CatalogScreen(),
        NexusRoutes.productDetail: (_) => const ProductDetailScreen(),
        NexusRoutes.cart: (_) => const CartScreen(),
        NexusRoutes.comparator: (_) => const ComparatorScreen(),
        NexusRoutes.pcBuilder: (_) => const PcBuilderScreen(),
      },
    );
  }
}
