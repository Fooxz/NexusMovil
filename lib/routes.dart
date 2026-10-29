// lib/routes.dart
//
// Nombres de rutas centralizados. Definirlos en un solo lugar evita
// errores de tipeo al navegar (Navigator.pushNamed(context, NexusRoutes.cart)).

class NexusRoutes {
  NexusRoutes._();

  /// Argumento opcional: `String` con el motivo ("para confirmar tu pedido").
  /// Devuelve `true` si el usuario quedó con sesión.
  static const login = '/login';
  static const signup = '/signup';
  static const forgotPassword = '/forgot-password';
  static const home = '/home';
  static const productDetail = '/product-detail';
  static const cart = '/cart';

  /// Argumento: `StoreCatalogArgs` (la tienda y su nombre visible).
  static const store = '/store';

  /// Exige sesión: se abre después de `ensureSignedIn`.
  static const checkout = '/checkout';
}
