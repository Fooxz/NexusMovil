import 'package:flutter_test/flutter_test.dart';
import '../../support/catalog_test_support.dart';

void main() {
  test('loads the initial catalog page', () async {
    final harness = CatalogControllerHarness(
      repository: CatalogFakeProductRepository(),
    );
    addTearDown(harness.dispose);

    final state = await harness.load();
    expect(state.productIds, [catalogGpu.id, catalogCpu.id]);
    expect(state.total, 2);
    expect(state.page, 0);
    expect(harness.repository.requests, hasLength(1));
  });
}
