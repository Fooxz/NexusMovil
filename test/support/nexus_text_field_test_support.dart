import 'package:flutter/material.dart';
import 'package:prueba01/widgets/nexus_widgets.dart';

Widget requiredEmailValidationApp(
  GlobalKey<FormState> formKey,
  ValueChanged<bool> onValidated,
) => MaterialApp(
  home: Scaffold(
    body: Form(
      key: formKey,
      child: Column(
        children: [
          NexusTextField(
            hint: 'Correo',
            validator: (value) =>
                value == null || value.isEmpty ? 'Campo obligatorio' : null,
          ),
          ElevatedButton(
            onPressed: () => onValidated(formKey.currentState!.validate()),
            child: const Text('Validar'),
          ),
        ],
      ),
    ),
  ),
);
