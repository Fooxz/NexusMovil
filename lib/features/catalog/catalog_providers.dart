import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/mock_product_repository.dart';
import 'domain/product.dart';
import 'domain/product_page.dart';
import 'domain/product_repository.dart';

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => MockProductRepository(),
);

final catalogPageProvider = FutureProvider<ProductPage>((ref) {
  // TODO 5C: replace with an AsyncNotifier for search and pagination.
  return ref
      .watch(productRepositoryProvider)
      .getProducts(page: 0, pageSize: 20);
});

final productDetailProvider = FutureProvider.autoDispose.family<Product?, String>(
  (ref, productId) => ref.watch(productRepositoryProvider).getById(productId),
);

final relatedProductsProvider =
    FutureProvider.autoDispose.family<List<Product>, String>(
      (ref, productId) => ref
          .watch(productRepositoryProvider)
          .getRelated(productId, limit: 2),
    );
