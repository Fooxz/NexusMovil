import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/theme/nexus_theme.dart';
import 'package:prueba01/widgets/nexus_widgets.dart';

import '../../support/catalog_test_support.dart';

void main() {
  testWidgets('detail reports an unknown product id', (tester) async {
    await pumpProductDetailScreen(
      tester,
      CatalogFakeProductRepository(),
      'missing',
    );
    await tester.pumpAndSettle();
    expect(find.text('Producto no encontrado'), findsOneWidget);
  });

  testWidgets('detail omits empty specification sections', (tester) async {
    await pumpProductDetailScreen(
      tester,
      CatalogFakeProductRepository(products: const [catalogCpu]),
      catalogCpu.id,
    );
    await tester.pumpAndSettle();
    expect(find.text('SPECS RÁPIDAS'), findsNothing);
    expect(find.text('ESPECIFICACIONES COMPLETAS'), findsNothing);
  });

  testWidgets('detail displays out-of-stock status in faint gray', (
    tester,
  ) async {
    await pumpProductDetailScreen(
      tester,
      CatalogFakeProductRepository(products: const [catalogOutOfStock]),
      catalogOutOfStock.id,
    );
    await tester.pumpAndSettle();

    final stockRow = tester.widget<NexusSpecRow>(
      find.byWidgetPredicate(
        (widget) => widget is NexusSpecRow && widget.label == 'ESTADO',
      ),
    );
    expect(stockRow.value, 'AGOTADO');
    expect(stockRow.valueColor, NexusColors.textFaint);
  });
}
