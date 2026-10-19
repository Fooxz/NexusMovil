import 'cart_models.dart';

/// Carrito (HU-009). Las operaciones guardadas exigen sesión y devuelven el
/// carrito actualizado. Los errores llegan como `AppFailure`: entre otros,
/// `OutOfStockFailure` y `QuantityUnavailableFailure` con el máximo.
abstract class CartRepository {
  /// Vista vigente (precio, proveedor, disponibilidad) de líneas guardadas en
  /// el dispositivo, para el carrito sin sesión. Omite ofertas inexistentes.
  Future<List<CartItem>> preview(List<CartEntry> entries);

  /// Carrito guardado del usuario con sesión (RF-054).
  Future<List<CartItem>> load();

  /// Suma [quantity] unidades a la línea de la oferta (la crea si no existe).
  Future<List<CartItem>> add(String offerId, int quantity);

  /// Fija la cantidad de la línea.
  Future<List<CartItem>> setQuantity(String offerId, int quantity);

  Future<List<CartItem>> remove(String offerId);

  Future<List<CartItem>> clear();

  /// Suma el carrito de invitado al guardado al iniciar sesión. Cada línea
  /// queda limitada al máximo disponible; las no disponibles se descartan.
  Future<List<CartItem>> merge(List<CartEntry> entries);
}
