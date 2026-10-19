import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/supabase_providers.dart';
import 'data/mock_product_repository.dart';
import 'data/supabase_product_repository.dart';
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

  final List<Product> items;
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
    List<Product>? items,
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

  /// La categoría solo se conserva si pertenece a la nueva familia; elegir
  /// "Todo" (`null`) la quita también.
  Future<void> setFamily(ProductFamily? family) {
    final filters = _current.filters;
    if (filters.family == family) return Future.value();
    final category = filters.category;
    return _applyFilters(
      filters.copyWith(
        family: family,
        category: category?.family == family ? category : null,
        brand: null,
      ),
    );
  }

  /// La categoría implica su familia.
  Future<void> setCategory(ProductCategory? category) {
    final filters = _current.filters;
    if (filters.category == category) return Future.value();
    return _applyFilters(
      filters.copyWith(
        category: category,
        family: category?.family ?? filters.family,
        brand: null,
      ),
    );
  }

  Future<void> setBrand(String? brand) =>
      _applyFilters(_current.filters.copyWith(brand: brand));

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
      final pageResult = await repository.getProducts(
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

/// Marcas para el filtro, según la familia y categoría seleccionadas.
final catalogBrandsProvider = FutureProvider.autoDispose<List<String>>((ref) {
  final scope = ref.watch(
    catalogControllerProvider.select((value) {
      final filters = value.asData?.value.filters;
      return (family: filters?.family, category: filters?.category);
    }),
  );
  return ref
      .watch(productRepositoryProvider)
      .getBrands(family: scope.family, category: scope.category);
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
