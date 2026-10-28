import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_failure.dart';
import '../../core/network/supabase_providers.dart';
import '../account/account_providers.dart';
import '../auth/auth_providers.dart';
import '../auth/data/mock_auth_repository.dart';
import '../catalog/catalog_providers.dart';
import '../catalog/data/mock_product_repository.dart';
import 'data/mock_cart_repository.dart';
import 'data/supabase_cart_repository.dart';
import 'domain/cart_models.dart';
import 'domain/cart_repository.dart';

/// Con los mocks de catálogo y cuentas usa el mock del carrito; si no, las
/// RPC de Supabase.
final cartRepositoryProvider = Provider<CartRepository>((ref) {
  final products = ref.watch(productRepositoryProvider);
  final auth = ref.watch(authRepositoryProvider);
  if (products is MockProductRepository && auth is MockAuthRepository) {
    return MockCartRepository(products, auth);
  }
  return SupabaseCartRepository.fromClient(ref.watch(supabaseClientProvider));
});

/// Líneas del carrito sin sesión. Viven en memoria mientras la app está
/// abierta; al iniciar sesión se suman al carrito guardado.
final guestCartProvider = NotifierProvider<GuestCartNotifier, List<CartEntry>>(
  GuestCartNotifier.new,
);

class GuestCartNotifier extends Notifier<List<CartEntry>> {
  @override
  List<CartEntry> build() => const [];

  void put(CartEntry entry) {
    final index = state.indexWhere((e) => e.offerId == entry.offerId);
    state = index < 0
        ? [...state, entry]
        : [...state.take(index), entry, ...state.skip(index + 1)];
  }

  void remove(String offerId) =>
      state = [for (final e in state) if (e.offerId != offerId) e];

  void clear() => state = const [];
}

/// Carrito visible: el guardado con sesión, o la vista previa del de invitado.
final cartControllerProvider =
    AsyncNotifierProvider<CartController, CartState>(CartController.new);

class CartController extends AsyncNotifier<CartState> {
  Future<void> _queue = Future.value();

  CartRepository get _repository => ref.read(cartRepositoryProvider);

  bool get _isGuest => ref.read(currentUserProvider) == null;

  @override
  Future<CartState> build() async {
    final repository = ref.watch(cartRepositoryProvider);
    final userId = ref.watch(currentUserProvider.select((user) => user?.id));

    if (userId == null) {
      return CartState(await repository.preview(ref.watch(guestCartProvider)));
    }

    // Roles exclusivos: las cuentas de tienda y de administración no compran.
    // No se pide su carrito guardado (el backend respondería CUSTOMER_ONLY) ni
    // se les suma el de invitado, que sigue en memoria al cerrar sesión.
    if (!await _accountCanBuy()) return CartState(const []);

    final guest = ref.read(guestCartProvider);
    if (guest.isEmpty) return CartState(await repository.load());

    // Recién inició sesión con un carrito de invitado: se suma al guardado.
    final merged = await repository.merge(guest);
    ref.read(guestCartProvider.notifier).clear();
    return CartState(merged);
  }

  /// Si no se puede leer la cuenta, como cliente: el backend decide.
  Future<bool> _accountCanBuy() async {
    try {
      return (await ref.watch(accountProvider.future))?.canBuy ?? true;
    } on Object {
      return true;
    }
  }

  /// Suma [quantity] unidades de la oferta. Lanza `OutOfStockFailure` o
  /// `QuantityUnavailableFailure` si no hay suficientes.
  Future<void> add(String offerId, {int quantity = 1}) => _serial(() async {
    if (_isGuest) {
      final current = _guestQuantity(offerId);
      await _putGuest(offerId, current + quantity);
      return;
    }
    _set(await _repository.add(offerId, quantity));
  });

  Future<void> setQuantity(String offerId, int quantity) => _serial(() async {
    if (_isGuest) {
      await _putGuest(offerId, quantity);
      return;
    }
    _set(await _repository.setQuantity(offerId, quantity));
  });

  Future<void> remove(String offerId) => _serial(() async {
    if (_isGuest) {
      ref.read(guestCartProvider.notifier).remove(offerId);
      return;
    }
    _set(await _repository.remove(offerId));
  });

  Future<void> clear() => _serial(() async {
    if (_isGuest) {
      ref.read(guestCartProvider.notifier).clear();
      return;
    }
    _set(await _repository.clear());
  });

  void _set(List<CartItem> items) => state = AsyncData(CartState(items));

  int _guestQuantity(String offerId) {
    for (final entry in ref.read(guestCartProvider)) {
      if (entry.offerId == offerId) return entry.quantity;
    }
    return 0;
  }

  /// Sin sesión no hay RPC que valide: se consulta la vista previa de la
  /// línea con la cantidad nueva y se aplican las mismas reglas.
  Future<void> _putGuest(String offerId, int quantity) async {
    if (quantity < 1) throw const ValidationFailure();
    final preview = await _repository.preview([
      CartEntry(offerId: offerId, quantity: quantity),
    ]);
    if (preview.isEmpty) throw const NotFoundFailure();
    final item = preview.single;
    if (!item.isAvailable) throw const OutOfStockFailure();
    if (quantity > item.maxQuantity) {
      throw QuantityUnavailableFailure(item.maxQuantity);
    }
    ref
        .read(guestCartProvider.notifier)
        .put(CartEntry(offerId: offerId, quantity: quantity));
  }

  /// Ejecuta las operaciones de a una: dos toques rápidos en "+" no deben
  /// calcular la cantidad sobre el mismo estado.
  Future<void> _serial(Future<void> Function() operation) {
    final next = _queue.then((_) => operation());
    _queue = next.then<void>((_) {}, onError: (_) {});
    return next;
  }
}

/// Unidades en el carrito, para el contador del ícono.
final cartItemCountProvider = Provider<int>(
  (ref) => ref.watch(
    cartControllerProvider.select((cart) => cart.value?.totalUnits ?? 0),
  ),
);
