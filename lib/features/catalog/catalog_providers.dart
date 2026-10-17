import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/mock_product_repository.dart';
import 'domain/product.dart';
import 'domain/product_repository.dart';

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => MockProductRepository(),
);

final catalogPageSizeProvider = Provider<int>((ref) => 20);

@immutable
class CatalogState {
  const CatalogState({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    this.query = '',
    this.category,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  final List<Product> items;
  final int total;
  final int page;
  final int pageSize;
  final String query;
  final ProductCategory? category;
  final bool isLoadingMore;
  final String? loadMoreError;

  factory CatalogState.initial({int pageSize = 20}) =>
      CatalogState(items: const [], total: 0, page: 0, pageSize: pageSize);

  CatalogState copyWith({
    List<Product>? items,
    int? total,
    int? page,
    int? pageSize,
    String? query,
    ProductCategory? category,
    bool? isLoadingMore,
    String? loadMoreError,
    bool clearLoadMoreError = false,
    bool clearCategory = false,
  }) {
    return CatalogState(
      items: items ?? this.items,
      total: total ?? this.total,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      query: query ?? this.query,
      category: clearCategory ? null : (category ?? this.category),
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
      query: '',
      category: null,
      preservePrevious: false,
    );
  }

  Future<void> setSearch(String value) async {
    final trimmed = value.trim();
    final current =
        state.asData?.value ??
        CatalogState.initial(pageSize: ref.read(catalogPageSizeProvider));
    final nextQuery = trimmed.isEmpty ? '' : trimmed;

    _searchDebounce?.cancel();
    _searchDebounce = null;
    if (current.query == nextQuery) return;

    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      final latest =
          state.asData?.value ??
          CatalogState.initial(pageSize: ref.read(catalogPageSizeProvider));
      unawaited(
        _loadPage(
          page: 0,
          pageSize: ref.read(catalogPageSizeProvider),
          query: nextQuery,
          category: latest.category,
          preservePrevious: true,
        ),
      );
    });
  }

  Future<void> setCategory(ProductCategory? category) async {
    final current =
        state.asData?.value ??
        CatalogState.initial(pageSize: ref.read(catalogPageSizeProvider));
    if (current.category == category) return;
    await _loadPage(
      page: 0,
      pageSize: ref.read(catalogPageSizeProvider),
      query: current.query,
      category: category,
      preservePrevious: true,
    );
  }

  Future<void> clearFilters() async {
    _searchDebounce?.cancel();
    _searchDebounce = null;
    final current =
        state.asData?.value ??
        CatalogState.initial(pageSize: ref.read(catalogPageSizeProvider));
    if (current.query.isEmpty && current.category == null) return;

    await _loadPage(
      page: 0,
      pageSize: ref.read(catalogPageSizeProvider),
      query: '',
      category: null,
      preservePrevious: true,
    );
  }

  Future<void> retry() async {
    _searchDebounce?.cancel();
    _searchDebounce = null;
    final current =
        state.asData?.value ??
        CatalogState.initial(pageSize: ref.read(catalogPageSizeProvider));
    await _loadPage(
      page: current.page,
      pageSize: ref.read(catalogPageSizeProvider),
      query: current.query,
      category: current.category,
      preservePrevious: true,
    );
  }

  Future<void> loadMore() async {
    final current =
        state.asData?.value ??
        CatalogState.initial(pageSize: ref.read(catalogPageSizeProvider));
    if (current.isLoadingMore || !current.hasMore) return;
    if (state.isLoading) return;
    await _loadPage(
      page: current.page + 1,
      pageSize: ref.read(catalogPageSizeProvider),
      query: current.query,
      category: current.category,
      preservePrevious: true,
      append: true,
    );
  }

  Future<CatalogState> _loadPage({
    required int page,
    required int pageSize,
    required String query,
    required ProductCategory? category,
    required bool preservePrevious,
    bool append = false,
  }) async {
    final repository = ref.read(productRepositoryProvider);
    final current =
        state.asData?.value ?? CatalogState.initial(pageSize: pageSize);
    final requestId = ++_requestVersion;
    final effectiveQuery = query.trim();

    if (preservePrevious) {
      state = AsyncValue<CatalogState>.data(
        current.copyWith(isLoadingMore: append),
      );
    }

    try {
      final pageResult = await repository.getProducts(
        page: page,
        pageSize: pageSize,
        search: effectiveQuery.isEmpty ? null : effectiveQuery,
        category: category,
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
        query: effectiveQuery,
        category: category,
        clearCategory: category == null,
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
