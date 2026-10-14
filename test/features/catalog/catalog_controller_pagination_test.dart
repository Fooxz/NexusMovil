import 'package:flutter_test/flutter_test.dart';
import '../../support/catalog_test_support.dart';

void main() {
  test('appends pages and stops after the final page', () async {
    final repository = CatalogFakeProductRepository(
      products: generateCatalogProducts(45),
    );
    final harness = CatalogControllerHarness(repository: repository);
    addTearDown(harness.dispose);
    await harness.load();

    await harness.controller.loadMore();
    expect(harness.state.items, hasLength(40));
    await harness.controller.loadMore();
    expect(harness.state.items, hasLength(45));
    await harness.controller.loadMore();
    expect(repository.requests, hasLength(3));
  });

  test('records load-more failure and clears it after retry', () async {
    final repository = createRetryablePageRepository();
    final harness = CatalogControllerHarness(repository: repository, pageSize: 2);
    addTearDown(harness.dispose);
    await harness.load();

    await expectLater(
      harness.controller.loadMore(),
      throwsA(isA<StateError>()),
    );
    expect(harness.state.loadMoreError, contains('page failure'));
    await harness.controller.loadMore();
    expect(harness.state.items, [catalogGpu, catalogCpu, catalogRam, catalogStorage]);
    expect(harness.state.loadMoreError, isNull);
  });
}
