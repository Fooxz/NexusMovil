import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/widgets/nexus_page.dart';

void main() {
  testWidgets('NexusPage.slivers displays the header and supplied slivers', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NexusPage.slivers(
          title: 'CATÁLOGO SLIVER',
          slivers: [
            SliverToBoxAdapter(child: Text('Contenido perezoso')),
          ],
        ),
      ),
    );

    expect(find.text('CATÁLOGO SLIVER'), findsOneWidget);
    expect(find.text('Contenido perezoso'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
