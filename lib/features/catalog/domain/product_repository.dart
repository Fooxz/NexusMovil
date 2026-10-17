import 'product.dart';
import 'product_page.dart';

abstract class ProductRepository {
  Future<ProductPage> getProducts({
    int page = 0,
    int pageSize = 20,
    String? search,
    ProductCategory? category,
  });

  Future<Product?> getById(String id);

  Future<List<Product>> getRelated(String id, {int limit = 2});
}
