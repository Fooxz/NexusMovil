import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/widgets/nexus_widgets.dart';
import 'support/nexus_text_field_test_support.dart';

void main() {
  testWidgets('controller receives entered text', (WidgetTester tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NexusTextField(hint: 'Nombre', controller: controller),
        ),
      ),
    );

    await tester.enterText(find.byType(NexusTextField), 'hola');

    expect(controller.text, 'hola');
  });

  testWidgets('onChanged receives entered text', (WidgetTester tester) async {
    String? changedText;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NexusTextField(
            hint: 'Buscar',
            onChanged: (value) => changedText = value,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(NexusTextField), 'rtx');

    expect(changedText, 'rtx');
  });

  testWidgets('validator displays its error inside a Form', (
    WidgetTester tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    var isValid = true;
    await tester.pumpWidget(
      requiredEmailValidationApp(formKey, (value) => isValid = value),
    );
    await tester.tap(find.text('Validar'));
    await tester.pump();

    expect(isValid, isFalse);
    expect(find.text('Campo obligatorio'), findsOneWidget);
  });

  testWidgets('validator can be provided without a Form', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NexusTextField(hint: 'Correo', validator: (_) => 'Inválido'),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('obscure hides entered text', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: NexusTextField(hint: 'Clave', obscure: true)),
      ),
    );

    await tester.enterText(find.byType(NexusTextField), 'secreto');

    expect(
      tester.widget<EditableText>(find.byType(EditableText)).obscureText,
      isTrue,
    );
  });

  testWidgets('disabled field does not accept input', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: NexusTextField(hint: 'Correo', enabled: false)),
      ),
    );

    await tester.enterText(find.byType(NexusTextField), 'hola');

    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      isEmpty,
    );
  });
}
