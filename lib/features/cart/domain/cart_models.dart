import '../../catalog/domain/product.dart';

/// Línea mínima del carrito de invitado: qué oferta y cuántas unidades.
class CartEntry {
  const CartEntry({required this.offerId, required this.quantity});

  final String offerId;
  final int quantity;

  CartEntry withQuantity(int quantity) =>
      CartEntry(offerId: offerId, quantity: quantity);

  Map<String, Object> toJson() => {'offerId': offerId, 'quantity': quantity};

  @override
  bool operator ==(Object other) =>
      other is CartEntry &&
      other.offerId == offerId &&
      other.quantity == quantity;

  @override
  int get hashCode => Object.hash(offerId, quantity);
}

/// Línea del carrito con los datos vigentes de su oferta: precio, proveedor y
/// cuántas unidades se pueden comprar (API_CONTRATO, parte 2).
class CartItem {
  const CartItem({
    required this.offerId,
    required this.quantity,
    required this.maxQuantity,
    required this.isAvailable,
    required this.unitPriceCents,
    this.oldPriceCents,
    required this.stockLevel,
    required this.providerId,
    required this.providerName,
    required this.productId,
    required this.productName,
    required this.brand,
    this.category,
    this.imageUrl,
  });

  final String offerId;
  final int quantity;

  /// Máximo comprable de esta oferta: el stock, con un tope por línea.
  final int maxQuantity;

  /// `false` si la oferta se pausó, se agotó o su proveedor no está activo.
  final bool isAvailable;
  final int unitPriceCents;
  final int? oldPriceCents;
  final StockLevel stockLevel;
  final String providerId;
  final String providerName;
  final String productId;
  final String productName;
  final String brand;

  /// `null` si el backend envía una categoría que la app no conoce.
  final ProductCategory? category;
  final String? imageUrl;

  int get subtotalCents => unitPriceCents * quantity;

  /// Quedan menos unidades que las que había en el carrito.
  bool get exceedsStock => isAvailable && quantity > maxQuantity;

  /// Se puede pagar tal cual está.
  bool get isPurchasable => isAvailable && quantity <= maxQuantity;

  bool get canIncrease => isAvailable && quantity < maxQuantity;
  bool get canDecrease => quantity > 1;

  bool get hasDiscount =>
      oldPriceCents != null && oldPriceCents! > unitPriceCents;
}

/// Líneas de un mismo proveedor: llegan en un envío propio (S-06, R-10).
class CartProviderGroup {
  const CartProviderGroup({
    required this.providerId,
    required this.providerName,
    required this.items,
  });

  final String providerId;
  final String providerName;
  final List<CartItem> items;
}

/// Carrito con sus valores derivados, calculados una sola vez (R3).
class CartState {
  CartState(List<CartItem> items)
    : items = List.unmodifiable(items),
      groups = _groupByProvider(items),
      totalUnits = items.fold(0, (sum, item) => sum + item.quantity),
      purchasableUnits = items
          .where((item) => item.isPurchasable)
          .fold(0, (sum, item) => sum + item.quantity),
      subtotalCents = items
          .where((item) => item.isPurchasable)
          .fold(0, (sum, item) => sum + item.subtotalCents),
      hasIssues = items.any((item) => !item.isPurchasable);

  CartState.empty() : this(const []);

  final List<CartItem> items;

  /// En el orden en que se agregó la primera línea de cada proveedor.
  final List<CartProviderGroup> groups;

  /// Todas las unidades, para el contador del ícono del carrito.
  final int totalUnits;

  /// Unidades que se pueden pagar ahora.
  final int purchasableUnits;

  /// Suma de las líneas que se pueden pagar, con IVA incluido. Supuesto: el
  /// envío no tiene costo adicional para el cliente.
  final int subtotalCents;

  /// Hay líneas agotadas o con más unidades de las disponibles.
  final bool hasIssues;

  bool get isEmpty => items.isEmpty;

  /// Se puede confirmar: hay algo que pagar y ninguna línea con problemas.
  bool get canCheckout => purchasableUnits > 0 && !hasIssues;

  CartItem? itemFor(String offerId) {
    for (final item in items) {
      if (item.offerId == offerId) return item;
    }
    return null;
  }

  static List<CartProviderGroup> _groupByProvider(List<CartItem> items) {
    final byProvider = <String, List<CartItem>>{};
    final names = <String, String>{};
    for (final item in items) {
      byProvider.putIfAbsent(item.providerId, () => []).add(item);
      names[item.providerId] = item.providerName;
    }
    return [
      for (final entry in byProvider.entries)
        CartProviderGroup(
          providerId: entry.key,
          providerName: names[entry.key]!,
          items: List.unmodifiable(entry.value),
        ),
    ];
  }
}
