import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/screens/home/home_screen.dart';

void main() {
  testWidgets('home literals use converted COP prices', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    expect(find.text('\$4.800.000'), findsOneWidget);
    expect(find.text('\$1.000.000'), findsOneWidget);
    expect(find.text('\$3.600.000'), findsOneWidget);
  });
}
