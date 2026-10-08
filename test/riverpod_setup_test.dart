import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final messageProvider = Provider<String>((ref) => 'valor real');

  test('reads a provider from a ProviderContainer', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(messageProvider), 'valor real');
  });

  test('overrides a provider in a ProviderContainer', () {
    final container = ProviderContainer(
      overrides: [messageProvider.overrideWithValue('valor falso')],
    );
    addTearDown(container.dispose);

    expect(container.read(messageProvider), 'valor falso');
  });

  testWidgets('reads a provider inside ProviderScope', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, child) {
              return Text(ref.watch(messageProvider));
            },
          ),
        ),
      ),
    );

    expect(find.text('valor real'), findsOneWidget);
  });
}
