import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/screens/shell/main_shell.dart';

/// Regresión: la grilla de categorías de Inicio calculaba
/// `(maxWidth - 16) / 3` y, con muy poco espacio (ventana angosta del
/// navegador), daba un ancho negativo: "BoxConstraints has a negative minimum
/// width" desde `home_screen.dart`.
void main() {
  Future<List<String>> layoutErrorsAt(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final errors = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details.exceptionAsString());
    try {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: MainShell())),
      );
      await tester.pump();
      // Ofertas y tiendas del repositorio simulado.
      await tester.pump(const Duration(seconds: 1));
    } finally {
      FlutterError.onError = previous;
    }
    return errors;
  }

  for (final width in [412.0, 360.0, 250.0, 120.0, 40.0, 32.1]) {
    testWidgets('Home never builds negative constraints at $width px', (
      tester,
    ) async {
      final errors = await layoutErrorsAt(tester, width);

      expect(
        errors.where((error) => error.contains('negative')),
        isEmpty,
        reason: errors.join('\n'),
      );
    });
  }

  for (final width in [412.0, 360.0, 320.0]) {
    testWidgets('Home lays out without any error on a $width px phone', (
      tester,
    ) async {
      expect(await layoutErrorsAt(tester, width), isEmpty);
    });
  }
}
