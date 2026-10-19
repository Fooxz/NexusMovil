import '../../../core/errors/app_failure.dart';
import '../../auth/data/mock_auth_repository.dart';
import '../../catalog/data/mock_product_repository.dart';
import '../../catalog/domain/product.dart';
import '../domain/cart_models.dart';
import '../domain/cart_repository.dart';

/// Carrito en memoria, por usuario del [MockAuthRepository], con las mismas
/// reglas que el backend: cantidad de 1 al máximo (stock con tope de
/// [maxQuantityPerItem]) y ofertas agotadas que no se agregan.
class MockCartRepository implements CartRepository {
  MockCartRepository(this._products, this._auth);

  static const maxQuantityPerItem = 10;

  final MockProductRepository _products;
  final MockAuthRepository _auth;
  final _savedByUser = <String, List<CartEntry>>{};

  List<CartEntry> get _saved {
    final userId = _auth.currentUser?.id ?? (throw const UnauthorizedFailure());
    return _savedByUser.putIfAbsent(userId, () => []);
  }

  @override
  Future<List<CartItem>> preview(List<CartEntry> entries) async =>
      _view(entries);

  @override
  Future<List<CartItem>> load() async => _view(_saved);

  @override
  Future<List<CartItem>> add(String offerId, int quantity) async {
    final saved = _saved;
    final index = saved.indexWhere((entry) => entry.offerId == offerId);
    final current = index < 0 ? 0 : saved[index].quantity;
    _check(offerId, current + quantity);
    final entry = CartEntry(offerId: offerId, quantity: current + quantity);
    index < 0 ? saved.add(entry) : saved[index] = entry;
    return _view(saved);
  }

  @override
  Future<List<CartItem>> setQuantity(String offerId, int quantity) async {
    final saved = _saved;
    _check(offerId, quantity);
    final index = saved.indexWhere((entry) => entry.offerId == offerId);
    final entry = CartEntry(offerId: offerId, quantity: quantity);
    index < 0 ? saved.add(entry) : saved[index] = entry;
    return _view(saved);
  }

  @override
  Future<List<CartItem>> remove(String offerId) async {
    final saved = _saved..removeWhere((entry) => entry.offerId == offerId);
    return _view(saved);
  }

  @override
  Future<List<CartItem>> clear() async {
    final saved = _saved..clear();
    return _view(saved);
  }

  @override
  Future<List<CartItem>> merge(List<CartEntry> entries) async {
    final saved = _saved;
    for (final guest in entries) {
      final max = _maxQuantity(guest.offerId);
      if (max == 0) continue;
      final index = saved.indexWhere((entry) => entry.offerId == guest.offerId);
      final current = index < 0 ? 0 : saved[index].quantity;
      final merged = guest.withQuantity(
        (current + guest.quantity).clamp(1, max),
      );
      index < 0 ? saved.add(merged) : saved[index] = merged;
    }
    return _view(saved);
  }

  int _maxQuantity(String offerId) {
    final offer = _products.offerById(offerId);
    if (offer == null) return 0;
    return offer.stockUnits.clamp(0, maxQuantityPerItem);
  }

  void _check(String offerId, int quantity) {
    if (quantity < 1) throw const ValidationFailure();
    if (_products.offerById(offerId) == null) throw const NotFoundFailure();
    final max = _maxQuantity(offerId);
    if (max == 0) throw const OutOfStockFailure();
    if (quantity > max) throw QuantityUnavailableFailure(max);
  }

  List<CartItem> _view(List<CartEntry> entries) => [
    for (final entry in entries)
      if (_products.offerById(entry.offerId) case final found?)
        CartItem(
          offerId: entry.offerId,
          quantity: entry.quantity,
          maxQuantity: _maxQuantity(entry.offerId),
          isAvailable: _maxQuantity(entry.offerId) > 0,
          unitPriceCents: found.offer.priceCents,
          oldPriceCents: found.offer.oldPriceCents,
          stockLevel: _maxQuantity(entry.offerId) > 0
              ? found.offer.stockLevel
              : StockLevel.outOfStock,
          providerId: found.offer.providerId,
          providerName: found.offer.providerName,
          productId: found.product.id,
          productName: found.product.name,
          brand: found.product.brand,
          category: found.product.category,
          imageUrl: found.product.imageUrl,
        ),
  ];
}
