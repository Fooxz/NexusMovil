import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/nexus_theme.dart';

/// Muestra la contraseña temporal una sola vez. NEXUS no la guarda: el
/// administrador la entrega por un canal seguro y la tienda la cambia en su
/// primer ingreso. Si se pierde, se regenera.
Future<void> showTemporaryPassword(
  BuildContext context, {
  required String storeName,
  required String accountEmail,
  required String password,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Contraseña temporal'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Cuenta de $storeName: $accountEmail', style: const TextStyle(fontSize: 12.5)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: NexusColors.bg,
              border: Border.all(color: NexusColors.cyan),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              password,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 15, color: Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Solo se muestra ahora: NEXUS no la guarda. Entrégala por un canal seguro. '
            'La tienda debe cambiarla en su primer ingreso; si se pierde, genera otra.',
            style: TextStyle(fontSize: 11.5, color: NexusColors.textDim),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: password));
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(content: Text('Contraseña copiada.')));
            }
          },
          child: const Text('Copiar'),
        ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Listo')),
      ],
    ),
  );
}
