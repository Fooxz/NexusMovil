import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/widgets/nexus_empty_state.dart';

void main() {
  testWidgets('shows its message and invokes the optional action', (
    WidgetTester tester,
  ) async {
    var actionCalled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NexusEmptyState(
            message: 'No hay productos',
            actionLabel: 'LIMPIAR FILTROS',
            onAction: () => actionCalled = true,
          ),
        ),
      ),
    );

    expect(find.text('No hay productos'), findsOneWidget);
    await tester.tap(find.text('LIMPIAR FILTROS'));
    expect(actionCalled, isTrue);
  });
}
