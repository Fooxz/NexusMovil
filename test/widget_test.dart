// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prueba01/core/utils/format_price.dart';
import 'package:prueba01/main.dart';
import 'package:prueba01/screens/home/home_screen.dart';
import 'package:prueba01/widgets/nexus_product_card.dart';

void main() {
  test('formats integer centavos as COP', () {
    expect(formatPrice(199900), '\$1.999');
    expect(formatPrice(5), '\$0');
    expect(formatPrice(-123456), '-\$1.235');
  });

  testWidgets('product card formats price and delegates tap', (
    WidgetTester tester,
  ) async {
    var wasTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NexusProductCard(
            icon: Icons.memory,
            gradientColors: const [Colors.black, Colors.grey],
            name: 'CPU',
            priceCents: 199900,
            onTap: () => wasTapped = true,
          ),
        ),
      ),
    );

    expect(find.text('\$1.999'), findsOneWidget);
    await tester.tap(find.byType(NexusProductCard));
    expect(wasTapped, isTrue);
  });

  testWidgets('renders the Nexus home screen without layout errors', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: HomeScreen())));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('NEXUS'), findsWidgets);
    expect(find.text('ARMA TU PC\nCON IA'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the app opens on Home without asking to sign in', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: NexusApp()));
    await tester.pumpAndSettle();

    expect(find.text('ARMA TU PC\nCON IA'), findsOneWidget);
    expect(find.text('INICIA SESIÓN'), findsNothing);
  });
}
