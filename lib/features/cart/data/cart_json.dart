import '../../catalog/domain/product.dart';
import '../domain/cart_models.dart';

/// Lectura de `{"items": [...]}` de las RPC del carrito (API_CONTRATO, parte 2).
/// Lanza `FormatException` si falta un campo obligatorio.
List<CartItem> cartItemsFromJson(Object? json) {
  if (json case {'items': List<Object?> items}) {
    return [for (final item in items) cartItemFromJson(item)];
  }
  throw FormatException('Carrito inválido', json);
}

CartItem cartItemFromJson(Object? json) {
  if (json case {
    'offerId': String offerId,
    'quantity': int quantity,
    'maxQuantity': int maxQuantity,
    'available': bool available,
    'priceCents': int priceCents,
    'stockLevel': String stockLevel,
    'providerId': String providerId,
    'providerName': String providerName,
    'productId': String productId,
    'productName': String productName,
    'brand': String brand,
  }) {
    final oldPriceCents = json['oldPriceCents'];
    final category = json['category'];
    final imageUrl = json['imageUrl'];
    return CartItem(
      offerId: offerId,
      quantity: quantity,
      maxQuantity: maxQuantity,
      isAvailable: available,
      unitPriceCents: priceCents,
      oldPriceCents: oldPriceCents is int ? oldPriceCents : null,
      stockLevel:
          StockLevel.values.asNameMap()[stockLevel] ?? StockLevel.outOfStock,
      providerId: providerId,
      providerName: providerName,
      productId: productId,
      productName: productName,
      brand: brand,
      category: category is String
          ? ProductCategory.values.asNameMap()[category]
          : null,
      imageUrl: imageUrl is String ? imageUrl : null,
    );
  }
  throw FormatException('Línea de carrito inválida', json);
}
