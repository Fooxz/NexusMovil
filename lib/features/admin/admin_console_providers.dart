import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/supabase_providers.dart';
import '../account/account_providers.dart';
import '../account/domain/account_models.dart';
import '../auth/auth_providers.dart';
import '../auth/data/mock_auth_repository.dart';
import '../catalog/domain/product.dart';
import '../provider_portal/domain/portal_models.dart';
import '../provider_portal/provider_portal_providers.dart';
import '../vendor/domain/vendor_models.dart';
import '../vendor/vendor_providers.dart';
import 'admin_providers.dart';
import 'data/mock_admin_console_repository.dart';
import 'data/supabase_admin_console_repository.dart';
import 'domain/admin_console_models.dart';
import 'domain/admin_console_repository.dart';

/// Con el mock de cuentas usa datos de ejemplo; si no, las RPC.
final adminConsoleRepositoryProvider = Provider<AdminConsoleRepository>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  if (auth is MockAuthRepository) {
    return MockAdminConsoleRepository(auth, ref.watch(mockDirectoryProvider), latency: auth.latency);
  }
  return SupabaseAdminConsoleRepository.fromClient(ref.watch(supabaseClientProvider));
});

final adminDashboardProvider = FutureProvider.autoDispose<AdminDashboard>((ref) {
  ref.watch(currentUserProvider.select((user) => user?.id));
  return ref.watch(adminConsoleRepositoryProvider).getDashboard();
});

// --- Proveedores -------------------------------------------------------------

typedef ProvidersQuery = ({String search, StoreStatus? status, ProviderSort sort});

final adminProvidersQueryProvider = NotifierProvider<AdminProvidersQueryNotifier, ProvidersQuery>(
  AdminProvidersQueryNotifier.new,
);

class AdminProvidersQueryNotifier extends Notifier<ProvidersQuery> {
  @override
  ProvidersQuery build() => (search: '', status: null, sort: ProviderSort.name);

  void setSearch(String search) {
    if (search.trim() != state.search) state = (search: search.trim(), status: state.status, sort: state.sort);
  }

  void setStatus(StoreStatus? status) => state = (search: state.search, status: status, sort: state.sort);

  void setSort(ProviderSort sort) => state = (search: state.search, status: state.status, sort: sort);
}

final adminProvidersProvider = FutureProvider.autoDispose<List<AdminProviderRow>>((ref) {
  final query = ref.watch(adminProvidersQueryProvider);
  return ref
      .watch(adminConsoleRepositoryProvider)
      .getProviders(search: query.search, status: query.status, sort: query.sort);
});

final providerOverviewProvider = FutureProvider.autoDispose.family<ProviderOverview, String>(
  (ref, id) => ref.watch(adminConsoleRepositoryProvider).getProviderOverview(id),
);

// --- Catálogo y moderación ---------------------------------------------------

typedef OffersQuery = ({
  String search,
  OfferModeration? moderation,
  QualityFlag? flag,
  bool anyFlag,
  ProductCategory? category,
});

/// Filtro de la moderación. El resumen lo cambia al abrir "piden revisión" o
/// "con alertas".
final adminOffersQueryProvider = NotifierProvider<AdminOffersQueryNotifier, OffersQuery>(AdminOffersQueryNotifier.new);

class AdminOffersQueryNotifier extends Notifier<OffersQuery> {
  @override
  OffersQuery build() => (search: '', moderation: null, flag: null, anyFlag: false, category: null);

  void setSearch(String search) {
    if (search.trim() == state.search) return;
    state = (
      search: search.trim(),
      moderation: state.moderation,
      flag: state.flag,
      anyFlag: state.anyFlag,
      category: state.category,
    );
  }

  void setModeration(OfferModeration? moderation) => state = (
    search: state.search,
    moderation: moderation,
    flag: state.flag,
    anyFlag: state.anyFlag,
    category: state.category,
  );

  /// [anyFlag]: con cualquier alerta; si no, solo [flag] (o todas si es null).
  void setFlag(QualityFlag? flag, {bool anyFlag = false}) => state = (
    search: state.search,
    moderation: state.moderation,
    flag: anyFlag ? null : flag,
    anyFlag: anyFlag,
    category: state.category,
  );

  void setCategory(ProductCategory? category) => state = (
    search: state.search,
    moderation: state.moderation,
    flag: state.flag,
    anyFlag: state.anyFlag,
    category: category,
  );
}

/// Páginas cargadas de la moderación, con los contadores de la primera.
class OffersList {
  const OffersList({required this.items, required this.page, this.loadingMore = false});

  final AdminOffersPage page;
  final List<AdminOffer> items;
  final bool loadingMore;
}

final adminOffersProvider = AsyncNotifierProvider.autoDispose<AdminOffersController, OffersList>(
  AdminOffersController.new,
);

class AdminOffersController extends AsyncNotifier<OffersList> {
  Future<AdminOffersPage> _load(OffersQuery query, int page) => ref
      .read(adminConsoleRepositoryProvider)
      .getOffers(
        search: query.search,
        moderation: query.moderation,
        flag: query.flag,
        anyFlag: query.anyFlag,
        category: query.category,
        page: page,
      );

  @override
  Future<OffersList> build() async {
    ref.watch(adminConsoleRepositoryProvider);
    final first = await _load(ref.watch(adminOffersQueryProvider), 0);
    return OffersList(items: first.items, page: first);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.loadingMore || !current.page.hasMore) return;
    state = AsyncData(OffersList(items: current.items, page: current.page, loadingMore: true));
    try {
      final next = await _load(ref.read(adminOffersQueryProvider), current.page.page + 1);
      state = AsyncData(OffersList(items: [...current.items, ...next.items], page: next));
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }
}

final adminOfferDetailProvider = FutureProvider.autoDispose.family<AdminOfferDetail, String>(
  (ref, offerId) => ref.watch(adminConsoleRepositoryProvider).getOffer(offerId),
);

// --- Pedidos ---------------------------------------------------------------

typedef AdminOrdersQuery = ({String search, VendorOrderStatus? status, String? providerId});

final adminOrdersQueryProvider = NotifierProvider<AdminOrdersQueryNotifier, AdminOrdersQuery>(
  AdminOrdersQueryNotifier.new,
);

class AdminOrdersQueryNotifier extends Notifier<AdminOrdersQuery> {
  @override
  AdminOrdersQuery build() => (search: '', status: null, providerId: null);

  void setSearch(String search) {
    if (search.trim() != state.search) {
      state = (search: search.trim(), status: state.status, providerId: state.providerId);
    }
  }

  void setStatus(VendorOrderStatus? status) =>
      state = (search: state.search, status: status, providerId: state.providerId);

  void setProvider(String? providerId) => state = (search: state.search, status: state.status, providerId: providerId);
}

final adminOrdersProvider = AsyncNotifierProvider.autoDispose<AdminOrdersController, PagedList<AdminOrderRow>>(
  AdminOrdersController.new,
);

class AdminOrdersController extends AsyncNotifier<PagedList<AdminOrderRow>> {
  static const pageSize = 20;

  Future<PortalPage<AdminOrderRow>> _load(AdminOrdersQuery query, int page) => ref
      .read(adminConsoleRepositoryProvider)
      .getOrders(search: query.search, status: query.status, providerId: query.providerId, page: page);

  @override
  Future<PagedList<AdminOrderRow>> build() async {
    ref.watch(adminConsoleRepositoryProvider);
    final first = await _load(ref.watch(adminOrdersQueryProvider), 0);
    return PagedList(items: first.items, total: first.total, page: 0);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.loadingMore || !current.hasMoreWith(pageSize)) return;
    state = AsyncData(PagedList(items: current.items, total: current.total, page: current.page, loadingMore: true));
    try {
      final next = await _load(ref.read(adminOrdersQueryProvider), current.page + 1);
      state = AsyncData(PagedList(items: [...current.items, ...next.items], total: next.total, page: next.page));
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }
}

final adminOrderDetailProvider = FutureProvider.autoDispose.family<AdminOrderDetail, String>(
  (ref, orderId) => ref.watch(adminConsoleRepositoryProvider).getOrder(orderId),
);

// --- Acciones ----------------------------------------------------------------

/// Acciones de la consola. Dejan el error en el estado y refrescan lo que
/// depende del cambio: el resumen siempre, y la lista y el detalle afectados.
final adminConsoleActionProvider = AsyncNotifierProvider.autoDispose<AdminConsoleActionController, void>(
  AdminConsoleActionController.new,
);

class AdminConsoleActionController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<T?> _run<T>(Future<T> Function(AdminConsoleRepository) action, void Function(T) refresh) async {
    state = const AsyncLoading();
    T? result;
    state = await AsyncValue.guard(() async {
      final value = await action(ref.read(adminConsoleRepositoryProvider));
      result = value;
      ref.invalidate(adminDashboardProvider);
      refresh(value);
    });
    return state.hasError ? null : result;
  }

  Future<AdminOfferDetail?> moderate(String offerId, ModerationAction action, {String? reason}) => _run(
    (repository) => repository.moderateOffer(offerId, action, reason: reason),
    (detail) => ref
      ..invalidate(adminOffersProvider)
      ..invalidate(adminOfferDetailProvider(offerId))
      ..invalidate(providerOverviewProvider(detail.offer.providerId))
      // La tienda que ve sus publicaciones en esta misma app (mock).
      ..invalidate(myOffersControllerProvider),
  );

  Future<List<AdminOffer>?> updateProduct(String productId, AdminProductInput product) =>
      _run((repository) => repository.updateProduct(productId, product), (offers) {
        ref.invalidate(adminOffersProvider);
        for (final offer in offers) {
          ref.invalidate(adminOfferDetailProvider(offer.offerId));
        }
      });

  Future<ProviderOverview?> addProviderNote(String id, ProviderNoteKind kind, String message) => _run(
    (repository) => repository.addProviderNote(id, kind, message),
    (_) => ref
      ..invalidate(providerOverviewProvider(id))
      ..invalidate(adminProvidersProvider),
  );

  /// El cambio de estado de una tienda va por [AdminRepository]: refresca
  /// también la ficha de la tienda y la lista de la parte 7.
  Future<void> setStoreStatus(String id, StoreStatus status, {String? reason}) => _run(
    (_) => ref.read(adminRepositoryProvider).setStoreStatus(id, status, reason: reason),
    (_) => ref
      ..invalidate(providerOverviewProvider(id))
      ..invalidate(adminProvidersProvider)
      ..invalidate(adminStoreProvider(id))
      ..invalidate(adminStoresProvider)
      ..invalidate(adminOffersProvider),
  );

  Future<AdminOrderDetail?> updateSubOrder(
    String orderId,
    String subOrderId,
    VendorOrderStatus status, {
    required String note,
    String? carrier,
    String? trackingNumber,
  }) => _run(
    (repository) => repository.updateSubOrderStatus(
      subOrderId,
      status,
      note: note,
      carrier: carrier,
      trackingNumber: trackingNumber,
    ),
    (_) => ref
      ..invalidate(adminOrderDetailProvider(orderId))
      ..invalidate(adminOrdersProvider)
      ..invalidate(adminProvidersProvider),
  );

  Future<AdminOrderDetail?> addOrderNote(String orderId, String message, {String? subOrderId}) => _run(
    (repository) => repository.addOrderNote(orderId, message, subOrderId: subOrderId),
    (_) => ref.invalidate(adminOrderDetailProvider(orderId)),
  );

  void clearError() => state = const AsyncData(null);
}
