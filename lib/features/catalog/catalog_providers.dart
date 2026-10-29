import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/supabase_providers.dart';
import 'data/mock_product_repository.dart';
import 'data/supabase_product_repository.dart';
import 'domain/catalog_offer.dart';
import 'domain/product.dart';
import 'domain/product_filters.dart';
import 'domain/product_repository.dart';

/// Único punto que decide entre el backend real y el mock: con Supabase
/// configurado (ver env.example.json) usa las RPC; sin él, el mock.
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  if (ref.watch(appEnvProvider).hasSupabase) {
    return SupabaseProductRepository.fromClient(
      ref.watch(supabaseClientProvider),
    );
  }
  return MockProductRepository();
});

final catalogPageSizeProvider = Provider<int>((ref) => 20);

@immutable
class CatalogState {
  const CatalogState({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    this.filters = const ProductFilters(),
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  /// Una tarjeta por oferta de cada tienda (API_CONTRATO, parte 6).
  final List<CatalogOffer> items;
  final int total;
  final int page;
  final int pageSize;
  final ProductFilters filters;
  final bool isLoadingMore;
  final String? loadMoreError;

  String get query => filters.search;
  ProductCategory? get category => filters.category;

  factory CatalogState.initial({int pageSize = 20}) =>
      CatalogState(items: const [], total: 0, page: 0, pageSize: pageSize);

  CatalogState copyWith({
    List<CatalogOffer>? items,
    int? total,
    int? page,
    int? pageSize,
    ProductFilters? filters,
    bool? isLoadingMore,
    String? loadMoreError,
    bool clearLoadMoreError = false,
  }) {
    return CatalogState(
      items: items ?? this.items,
      total: total ?? this.total,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      filters: filters ?? this.filters,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreError: clearLoadMoreError
          ? null
          : (loadMoreError ?? this.loadMoreError),
    );
  }

  bool get hasMore => (page + 1) * pageSize < total;
}

final catalogControllerProvider =
    AsyncNotifierProvider<CatalogController, CatalogState>(
      CatalogController.new,
    );

final catalogPageProvider = Provider<AsyncValue<CatalogState>>(
  (ref) => ref.watch(catalogControllerProvider),
);

class CatalogController extends AsyncNotifier<CatalogState> {
  Timer? _searchDebounce;
  int _requestVersion = 0;

  @override
  FutureOr<CatalogState> build() async {
    ref.onDispose(() => _searchDebounce?.cancel());
    final pageSize = ref.read(catalogPageSizeProvider);
    return _loadPage(
      page: 0,
      pageSize: pageSize,
      filters: const ProductFilters(),
      preservePrevious: false,
    );
  }

  CatalogState get _current =>
      state.asData?.value ??
      CatalogState.initial(pageSize: ref.read(catalogPageSizeProvider));

  Future<void> setSearch(String value) async {
    final nextQuery = value.trim();

    _searchDebounce?.cancel();
    _searchDebounce = null;
    if (_current.query == nextQuery) return;

    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(_applyFilters(_current.filters.copyWith(search: nextQuery)));
    });
  }

  /// `null` muestra todas las piezas. La marca y la tienda se quitan: pueden
  /// no tener piezas de la nueva categoría.
  Future<void> setCategory(ProductCategory? category) {
    final filters = _current.filters;
    if (filters.category == category) return Future.value();
    return _applyFilters(
      filters.copyWith(category: category, brand: null, providerId: null),
    );
  }

  Future<void> setBrand(String? brand) =>
      _applyFilters(_current.filters.copyWith(brand: brand));

  /// Filtro por tienda (id). `null` muestra todas.
  Future<void> setStore(String? providerId) =>
      _applyFilters(_current.filters.copyWith(providerId: providerId));

  Future<void> setPriceRange({int? minPriceCents, int? maxPriceCents}) =>
      _applyFilters(
        _current.filters.copyWith(
          minPriceCents: minPriceCents,
          maxPriceCents: maxPriceCents,
        ),
      );

  Future<void> setSort(ProductSort sort) =>
      _applyFilters(_current.filters.copyWith(sort: sort));

  /// Quita búsqueda y filtros; conserva el orden.
  Future<void> clearFilters() async {
    _searchDebounce?.cancel();
    _searchDebounce = null;
    final filters = _current.filters;
    if (!filters.hasActiveFilters) return;
    await _applyFilters(ProductFilters(sort: filters.sort));
  }

  Future<void> retry() async {
    _searchDebounce?.cancel();
    _searchDebounce = null;
    final current = _current;
    await _loadPage(
      page: current.page,
      pageSize: ref.read(catalogPageSizeProvider),
      filters: current.filters,
      preservePrevious: true,
    );
  }

  Future<void> loadMore() async {
    final current = _current;
    if (current.isLoadingMore || !current.hasMore) return;
    if (state.isLoading) return;
    await _loadPage(
      page: current.page + 1,
      pageSize: ref.read(catalogPageSizeProvider),
      filters: current.filters,
      preservePrevious: true,
      append: true,
    );
  }

  Future<void> _applyFilters(ProductFilters next) async {
    if (next == _current.filters) return;
    await _loadPage(
      page: 0,
      pageSize: ref.read(catalogPageSizeProvider),
      filters: next,
      preservePrevious: true,
    );
  }

  Future<CatalogState> _loadPage({
    required int page,
    required int pageSize,
    required ProductFilters filters,
    required bool preservePrevious,
    bool append = false,
  }) async {
    final repository = ref.read(productRepositoryProvider);
    final current =
        state.asData?.value ?? CatalogState.initial(pageSize: pageSize);
    final requestId = ++_requestVersion;
    final effectiveFilters = filters.copyWith(search: filters.search.trim());

    if (preservePrevious) {
      state = AsyncValue<CatalogState>.data(
        current.copyWith(isLoadingMore: append),
      );
    }

    try {
      final pageResult = await repository.getOffers(
        page: page,
        pageSize: pageSize,
        filters: effectiveFilters,
      );

      if (requestId != _requestVersion) {
        return current;
      }

      final mergedItems = append
          ? [...current.items, ...pageResult.items]
          : pageResult.items;
      final nextState = current.copyWith(
        items: mergedItems,
        total: pageResult.total,
        page: pageResult.page,
        pageSize: pageSize,
        filters: effectiveFilters,
        isLoadingMore: false,
        clearLoadMoreError: true,
      );
      state = AsyncValue.data(nextState);
      return nextState;
    } catch (error, stackTrace) {
      if (requestId != _requestVersion) {
        return current;
      }
      final touched = current.copyWith(
        isLoadingMore: false,
        loadMoreError: error.toString(),
      );
      if (preservePrevious) {
        state = AsyncValue<CatalogState>.data(touched);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

/// Marcas para el filtro, según la categoría seleccionada.
final catalogBrandsProvider = FutureProvider.autoDispose<List<String>>((ref) {
  final category = ref.watch(
    catalogControllerProvider.select(
      (value) => value.asData?.value.filters.category,
    ),
  );
  return ref.watch(productRepositoryProvider).getBrands(category: category);
});

/// Tiendas para el filtro, según la categoría seleccionada.
final catalogStoresProvider = FutureProvider.autoDispose<List<CatalogStore>>((ref) {
  final category = ref.watch(
    catalogControllerProvider.select(
      (value) => value.asData?.value.filters.category,
    ),
  );
  return ref.watch(productRepositoryProvider).getStores(category: category);
});

final productDetailProvider = FutureProvider.autoDispose
    .family<Product?, String>(
      (ref, productId) =>
          ref.watch(productRepositoryProvider).getById(productId),
    );

final relatedProductsProvider = FutureProvider.autoDispose
    .family<List<Product>, String>(
      (ref, productId) =>
          ref.watch(productRepositoryProvider).getRelated(productId, limit: 2),
    );

// --- Catálogo de una tienda ------------------------------------------------

/// Ofertas visibles de una tienda, con su búsqueda y tipo de pieza. Las
/// páginas cargadas se acumulan ("Cargar más").
@immutable
class StoreCatalogState {
  const StoreCatalogState({
    required this.items,
    required this.total,
    required this.page,
    required this.filters,
    this.isLoadingMore = false,
    this.isRefreshing = false,
  });

  final List<CatalogOffer> items;
  final int total;
  final int page;

  /// Siempre con el `providerId` de la tienda.
  final ProductFilters filters;
  final bool isLoadingMore;

  /// Cargando la primera página con filtros nuevos: se conservan los items
  /// anteriores mientras tanto.
  final bool isRefreshing;

  bool hasMoreWith(int pageSize) => (page + 1) * pageSize < total;
}

final storeCatalogProvider = AsyncNotifierProvider.autoDispose
    .family<StoreCatalogController, StoreCatalogState, String>(StoreCatalogController.new);

class StoreCatalogController extends AsyncNotifier<StoreCatalogState> {
  StoreCatalogController(this.storeId);

  final String storeId;
  int _version = 0;

  Future<OfferPage> _load(ProductFilters filters, int page) => ref
      .read(productRepositoryProvider)
      .getOffers(page: page, pageSize: ref.read(catalogPageSizeProvider), filters: filters);

  @override
  Future<StoreCatalogState> build() async {
    final filters = ProductFilters(providerId: storeId);
    final first = await _load(filters, 0);
    return StoreCatalogState(items: first.items, total: first.total, page: 0, filters: filters);
  }

  /// Cambia la búsqueda o el tipo de pieza y vuelve a la primera página.
  Future<void> setFilters({String? search, Object? category = _keep}) async {
    final current = state.value?.filters ?? ProductFilters(providerId: storeId);
    final filters = current.copyWith(
      search: search?.trim(),
      category: identical(category, _keep) ? current.category : category,
    );
    if (filters == current) return;
    final version = ++_version;
    if (state.value case final previous?) {
      state = AsyncData(StoreCatalogState(
        items: previous.items,
        total: previous.total,
        page: previous.page,
        filters: filters,
        isRefreshing: true,
      ));
    }
    final result = await AsyncValue.guard(() async {
      final first = await _load(filters, 0);
      return StoreCatalogState(items: first.items, total: first.total, page: 0, filters: filters);
    });
    if (version == _version) state = result;
  }

  Future<void> loadMore() async {
    final current = state.value;
    final pageSize = ref.read(catalogPageSizeProvider);
    if (current == null || current.isLoadingMore || current.isRefreshing || !current.hasMoreWith(pageSize)) {
      return;
    }
    state = AsyncData(StoreCatalogState(
      items: current.items,
      total: current.total,
      page: current.page,
      filters: current.filters,
      isLoadingMore: true,
    ));
    try {
      final next = await _load(current.filters, current.page + 1);
      state = AsyncData(StoreCatalogState(
        items: [...current.items, ...next.items],
        total: next.total,
        page: next.page,
        filters: current.filters,
      ));
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }
}

const _keep = Object();

// --- Inicio ----------------------------------------------------------------

/// Ofertas del inicio: las de mayor descuento con stock entre las primeras 50
/// del catálogo. `discounted` es falso si ninguna tiene descuento y se
/// muestran las primeras como destacadas.
final homeDealsProvider =
    FutureProvider.autoDispose<({List<CatalogOffer> items, bool discounted})>((ref) async {
      final page = await ref.watch(productRepositoryProvider).getOffers(pageSize: 50);
      final deals = page.items
          .where((offer) => offer.hasDiscount && offer.stockLevel != StockLevel.outOfStock)
          .toList()
        ..sort((a, b) => b.discountPercent.compareTo(a.discountPercent));
      return deals.isNotEmpty
          ? (items: deals.take(4).toList(), discounted: true)
          : (items: page.items.take(4).toList(), discounted: false);
    });

/// Tiendas con piezas visibles, para el inicio.
final homeStoresProvider = FutureProvider.autoDispose<List<CatalogStore>>(
  (ref) => ref.watch(productRepositoryProvider).getStores(),
);
