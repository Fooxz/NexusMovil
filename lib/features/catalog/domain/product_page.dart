import 'product.dart';

class ProductPage {
  const ProductPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<Product> items;
  final int total;
  final int page;
  final int pageSize;

  bool get hasMore => (page + 1) * pageSize < total;
}
