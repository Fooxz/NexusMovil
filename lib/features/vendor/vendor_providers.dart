import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/supabase_providers.dart';
import '../auth/auth_providers.dart';
import '../auth/data/mock_auth_repository.dart';
import '../provider_portal/domain/portal_models.dart';
import '../provider_portal/provider_portal_providers.dart';
import 'data/mock_vendor_repository.dart';
import 'data/supabase_vendor_repository.dart';
import 'domain/vendor_models.dart';
import 'domain/vendor_repository.dart';

/// Con el mock de cuentas usa una tienda de ejemplo; si no, las RPC.
final vendorRepositoryProvider = Provider<VendorRepository>((ref) {
  if (ref.watch(authRepositoryProvider) is MockAuthRepository) return MockVendorRepository();
  return SupabaseVendorRepository.fromClient(ref.watch(supabaseClientProvider));
});

/// Resumen del negocio. Otra cuenta, otra tienda.
final vendorDashboardProvider = FutureProvider.autoDispose<VendorDashboard>((ref) {
  ref.watch(currentUserProvider.select((user) => user?.id));
  return ref.watch(vendorRepositoryProvider).getDashboard();
});

// --- Pedidos ---------------------------------------------------------------

typedef OrdersQuery = ({VendorOrderStatus? status, String search});

/// Filtro de la lista de pedidos. El resumen lo cambia al abrir "Nuevos".
final vendorOrdersQueryProvider = NotifierProvider<VendorOrdersQueryNotifier, OrdersQuery>(
  VendorOrdersQueryNotifier.new,
);

class VendorOrdersQueryNotifier extends Notifier<OrdersQuery> {
  @override
  OrdersQuery build() => (status: null, search: '');

  void setStatus(VendorOrderStatus? status) => state = (status: status, search: state.search);

  void setSearch(String search) {
    if (search.trim() != state.search) state = (status: state.status, search: search.trim());
  }
}

/// Páginas cargadas de la lista de pedidos.
class PagedList<T> {
  const PagedList({required this.items, required this.total, required this.page, this.loadingMore = false});

  final List<T> items;
  final int total;
  final int page;
  final bool loadingMore;

  bool hasMoreWith(int pageSize) => (page + 1) * pageSize < total;
}

final vendorOrdersProvider = AsyncNotifierProvider.autoDispose<VendorOrdersController, PagedList<VendorOrder>>(
  VendorOrdersController.new,
);

class VendorOrdersController extends AsyncNotifier<PagedList<VendorOrder>> {
  static const pageSize = 20;

  @override
  Future<PagedList<VendorOrder>> build() async {
    ref.watch(currentUserProvider.select((user) => user?.id));
    final query = ref.watch(vendorOrdersQueryProvider);
    final first = await ref
        .watch(vendorRepositoryProvider)
        .getOrders(status: query.status, search: query.search);
    return PagedList(items: first.items, total: first.total, page: 0);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.loadingMore || !current.hasMoreWith(pageSize)) return;
    final query = ref.read(vendorOrdersQueryProvider);
    state = AsyncData(PagedList(items: current.items, total: current.total, page: current.page, loadingMore: true));
    try {
      final next = await ref
          .read(vendorRepositoryProvider)
          .getOrders(status: query.status, search: query.search, page: current.page + 1);
      state = AsyncData(PagedList(items: [...current.items, ...next.items], total: next.total, page: next.page));
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }
}

final vendorOrderDetailProvider = FutureProvider.autoDispose.family<VendorOrderDetail, String>(
  (ref, id) => ref.watch(vendorRepositoryProvider).getOrder(id),
);

/// Cambia el estado de un pedido y refresca lo que depende de él: la lista,
/// el resumen y el inventario (rechazar o cancelar devuelve stock).
final orderActionControllerProvider = AsyncNotifierProvider.autoDispose<OrderActionController, void>(
  OrderActionController.new,
);

class OrderActionController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Devuelve el detalle actualizado, o `null` si falló (el error queda en el
  /// estado).
  Future<VendorOrderDetail?> change(
    String id,
    VendorOrderStatus status, {
    String? note,
    String? carrier,
    String? trackingNumber,
  }) async {
    state = const AsyncLoading();
    VendorOrderDetail? result;
    state = await AsyncValue.guard(() async {
      result = await ref
          .read(vendorRepositoryProvider)
          .updateOrderStatus(id, status, note: note, carrier: carrier, trackingNumber: trackingNumber);
      ref
        ..invalidate(vendorOrderDetailProvider(id))
        ..invalidate(vendorOrdersProvider)
        ..invalidate(vendorDashboardProvider)
        ..invalidate(inventoryProvider);
      if (status == VendorOrderStatus.rejected || status == VendorOrderStatus.cancelled) {
        ref.invalidate(myOffersControllerProvider);
      }
    });
    return state.hasError ? null : result;
  }

  void clearError() => state = const AsyncData(null);
}

// --- Inventario ------------------------------------------------------------

typedef InventoryQuery = ({StockAlert? alert, String search});

final inventoryQueryProvider = NotifierProvider<InventoryQueryNotifier, InventoryQuery>(
  InventoryQueryNotifier.new,
);

class InventoryQueryNotifier extends Notifier<InventoryQuery> {
  @override
  InventoryQuery build() => (alert: null, search: '');

  void setAlert(StockAlert? alert) => state = (alert: alert, search: state.search);

  void setSearch(String search) {
    if (search.trim() != state.search) state = (alert: state.alert, search: search.trim());
  }
}

final inventoryProvider = AsyncNotifierProvider.autoDispose<InventoryController, InventoryPage>(
  InventoryController.new,
);

class InventoryController extends AsyncNotifier<InventoryPage> {
  bool _loadingMore = false;

  bool get loadingMore => _loadingMore;

  @override
  Future<InventoryPage> build() {
    ref.watch(currentUserProvider.select((user) => user?.id));
    final query = ref.watch(inventoryQueryProvider);
    return ref.watch(vendorRepositoryProvider).getInventory(alert: query.alert, search: query.search);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || _loadingMore || !current.hasMore) return;
    final query = ref.read(inventoryQueryProvider);
    _loadingMore = true;
    try {
      final next = await ref
          .read(vendorRepositoryProvider)
          .getInventory(alert: query.alert, search: query.search, page: current.page + 1);
      state = AsyncData(InventoryPage(
        items: [...current.items, ...next.items],
        total: next.total,
        page: next.page,
        pageSize: next.pageSize,
        allCount: next.allCount,
        lowCount: next.lowCount,
        outCount: next.outCount,
      ));
    } finally {
      _loadingMore = false;
    }
  }
}

final stockMovementsProvider = FutureProvider.autoDispose.family<PortalPage<StockMovement>, String?>(
  (ref, productId) => ref.watch(vendorRepositoryProvider).getMovements(productId: productId),
);

/// Movimientos manuales y stock mínimo. Al terminar refresca el inventario,
/// el resumen, el historial y "Mis publicaciones" (muestran el stock).
final stockActionControllerProvider = AsyncNotifierProvider.autoDispose<StockActionController, void>(
  StockActionController.new,
);

class StockActionController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<bool> adjust(String productId, StockMovementKind kind, int quantity, String reason) =>
      _run(productId, (repository) => repository.adjustStock(productId, kind, quantity, reason));

  Future<bool> setMinStock(String productId, int minStock) =>
      _run(productId, (repository) => repository.setMinStock(productId, minStock));

  Future<bool> _run(String productId, Future<InventoryItem> Function(VendorRepository) action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await action(ref.read(vendorRepositoryProvider));
      ref
        ..invalidate(inventoryProvider)
        ..invalidate(vendorDashboardProvider)
        ..invalidate(stockMovementsProvider(productId))
        ..invalidate(stockMovementsProvider(null))
        ..invalidate(myOffersControllerProvider)
        ..invalidate(myOfferDetailProvider(productId));
    });
    return !state.hasError;
  }

  void clearError() => state = const AsyncData(null);
}
