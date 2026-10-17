import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/screens/cart/cart_screen.dart';
import 'package:prueba01/screens/home/home_screen.dart';
import 'package:prueba01/screens/pc_builder/pc_builder_screen.dart';

void main() {
  testWidgets('home literals use converted COP prices', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    expect(find.text('\$4.800.000'), findsOneWidget);
    expect(find.text('\$1.000.000'), findsOneWidget);
    expect(find.text('\$3.600.000'), findsOneWidget);
  });

  testWidgets('cart literals and total use converted COP prices', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CartScreen()));

    expect(find.text('\$7.996.000'), findsNWidgets(2));
    expect(find.text('\$2.000.000'), findsOneWidget);
    expect(find.text('\$4.000.000'), findsOneWidget);
    expect(find.text('\$11.996.000'), findsNWidgets(2));
  });

  testWidgets('PC builder items and fixed total use converted COP prices', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PcBuilderScreen()));

    expect(find.text('\$3.196.000'), findsNWidgets(2));
    expect(find.text('\$1.996.000'), findsNWidgets(2));
    expect(find.text('\$4.996.000'), findsNWidgets(2));
    expect(find.text('\$552.000'), findsOneWidget);
    expect(find.text('\$996.000'), findsNWidgets(2));
    expect(find.text('\$556.000'), findsNWidgets(2));
    expect(find.text('\$156.000'), findsNWidgets(2));
    expect(find.text('\$12.448.000'), findsOneWidget);
  });
}
