// lib/routes.dart
//
// Nombres de rutas centralizados. Definirlos en un solo lugar evita
// errores de tipeo al navegar (Navigator.pushNamed(context, NexusRoutes.cart)).

class NexusRoutes {
  NexusRoutes._();

  static const login = '/login';
  static const signup = '/signup';
  static const home = '/home';
  static const catalog = '/catalog';
  static const productDetail = '/product-detail';
  static const cart = '/cart';
  static const comparator = '/comparator';
  static const pcBuilder = '/pc-builder';
}
