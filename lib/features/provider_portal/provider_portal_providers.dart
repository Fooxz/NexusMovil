import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/supabase_providers.dart';
import '../account/account_providers.dart';
import '../auth/auth_providers.dart';
import '../auth/data/mock_auth_repository.dart';
import '../catalog/catalog_providers.dart';
import '../catalog/data/mock_product_repository.dart';
import '../catalog/domain/product.dart';
import 'data/mock_portal_repository.dart';
import 'data/product_image_picker.dart';
import 'data/supabase_portal_repository.dart';
import 'domain/portal_models.dart';
import 'domain/portal_repository.dart';

/// Con el mock de cuentas usa el mock; si no, las RPC de Supabase.
final providerPortalRepositoryProvider = Provider<ProviderPortalRepository>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  if (auth is MockAuthRepository) {
    final products = ref.watch(productRepositoryProvider);
    return MockPortalRepository(
      auth,
      ref.watch(mockDirectoryProvider),
      products is MockProductRepository ? products : MockProductRepository(latency: auth.latency),
      latency: auth.latency,
    );
  }
  return SupabasePortalRepository.fromClient(ref.watch(supabaseClientProvider));
});

final productImagePickerProvider = Provider<ProductImagePicker>((ref) => GalleryImagePicker());

/// Plantilla de atributos por categoría. No cambia mientras la app está
/// abierta.
final attributeTemplateProvider = FutureProvider.family<List<AttributeDefinition>, ProductCategory>(
  (ref, category) => ref.watch(providerPortalRepositoryProvider).getAttributeTemplate(category),
);

final myOfferDetailProvider = FutureProvider.autoDispose.family<MyOfferDetail, String>(
  (ref, productId) => ref.watch(providerPortalRepositoryProvider).getMyOffer(productId),
);

/// Búsqueda de fichas para publicar sobre un producto existente.
typedef SheetQuery = ({String search, ProductCategory? category});

final sheetSearchProvider = FutureProvider.autoDispose.family<PortalPage<CatalogSheet>, SheetQuery>(
  (ref, query) => ref
      .watch(providerPortalRepositoryProvider)
      .searchSheets(search: query.search, category: query.category),
);

// --- Mis publicaciones ---------------------------------------------------

@immutable
class MyOffersState {
  const MyOffersState({
    this.status,
    this.items = const [],
    this.total = 0,
    this.page = 0,
    this.pageSize = 20,
    this.isLoadingMore = false,
  });

  /// `null`: todas menos las retiradas.
  final OfferStatus? status;
  final List<MyOffer> items;
  final int total;
  final int page;
  final int pageSize;
  final bool isLoadingMore;

  bool get hasMore => (page + 1) * pageSize < total;
}

/// Filtro de "Mis publicaciones". `null`: todas menos las retiradas.
final myOffersStatusProvider = NotifierProvider<MyOffersStatusNotifier, OfferStatus?>(
  MyOffersStatusNotifier.new,
);

class MyOffersStatusNotifier extends Notifier<OfferStatus?> {
  @override
  OfferStatus? build() => null;

  void select(OfferStatus? status) => state = status;
}

final myOffersControllerProvider = AsyncNotifierProvider<MyOffersController, MyOffersState>(
  MyOffersController.new,
);

class MyOffersController extends AsyncNotifier<MyOffersState> {
  @override
  Future<MyOffersState> build() {
    // Otra cuenta, otra tienda.
    ref.watch(currentUserProvider.select((user) => user?.id));
    return _load(status: ref.watch(myOffersStatusProvider), page: 0);
  }

  Future<MyOffersState> _load({required OfferStatus? status, required int page}) async {
    final result = await ref
        .read(providerPortalRepositoryProvider)
        .getMyOffers(status: status, page: page);
    return MyOffersState(
      status: status,
      items: result.items,
      total: result.total,
      page: result.page,
      pageSize: result.pageSize,
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncData(MyOffersState(
      status: current.status,
      items: current.items,
      total: current.total,
      page: current.page,
      pageSize: current.pageSize,
      isLoadingMore: true,
    ));
    final next = await AsyncValue.guard(() => _load(status: current.status, page: current.page + 1));
    state = next.whenData((page) => MyOffersState(
      status: page.status,
      items: [...current.items, ...page.items],
      total: page.total,
      page: page.page,
      pageSize: page.pageSize,
    ));
  }
}

// --- Acciones --------------------------------------------------------------

/// Crear, editar o retirar. Al terminar, refresca la lista y el detalle. Los
/// formularios leen el error del estado (por ejemplo, `ProductExistsFailure`).
final portalActionControllerProvider = AsyncNotifierProvider.autoDispose<PortalActionController, void>(
  PortalActionController.new,
);

class PortalActionController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Devuelve la publicación resultante, o `null` si falló.
  Future<MyOfferDetail?> run(Future<MyOfferDetail> Function(ProviderPortalRepository) action) async {
    state = const AsyncLoading();
    MyOfferDetail? result;
    state = await AsyncValue.guard(() async {
      result = await action(ref.read(providerPortalRepositoryProvider));
      ref
        ..invalidate(myOffersControllerProvider)
        ..invalidate(myOfferDetailProvider(result!.offer.productId))
        ..invalidate(sheetSearchProvider);
    });
    return state.hasError ? null : result;
  }

  void clearError() => state = const AsyncData(null);
}
