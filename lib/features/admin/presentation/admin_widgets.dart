import 'package:flutter/material.dart';

import '../../../theme/nexus_theme.dart';
import '../../../widgets/nexus_widgets.dart';
import '../../account/domain/account_models.dart';
import '../../provider_portal/domain/portal_models.dart';
import '../domain/admin_console_models.dart';

const amber = Color(0xFFFFC857);

Color storeStatusColor(StoreStatus status) => switch (status) {
  StoreStatus.active => NexusColors.green,
  StoreStatus.pending => amber,
  StoreStatus.suspended || StoreStatus.blocked || StoreStatus.deactivated || StoreStatus.rejected => NexusColors.pink,
};

Color moderationColor(OfferModeration moderation) => switch (moderation) {
  OfferModeration.approved => NexusColors.green,
  OfferModeration.review => amber,
  OfferModeration.hidden || OfferModeration.rejected => NexusColors.pink,
};

/// "85 %", o "—" sin pedidos cerrados.
String percentLabel(double? rate) => rate == null ? '—' : '${(rate * 100).round()} %';

/// Etiquetas de las alertas de calidad de una oferta.
class QualityFlagTags extends StatelessWidget {
  const QualityFlagTags(this.flags, {super.key});

  final List<QualityFlag> flags;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final flag in flags)
        NexusTag(flag.label.toUpperCase(), color: flag == QualityFlag.priceAnomaly ? amber : NexusColors.pink),
    ],
  );
}

/// Pide el texto de una acción que lo exige (motivo, observación). Devuelve
/// null si el administrador cancela. Con [required] en false acepta vacío.
Future<String?> showReasonDialog(
  BuildContext context, {
  required String title,
  required String label,
  required String action,
  String? message,
  bool required = true,
  int maxLength = 300,
}) => showDialog<String>(
  context: context,
  builder: (context) => _ReasonDialog(
    title: title,
    label: label,
    action: action,
    message: message,
    required: required,
    maxLength: maxLength,
  ),
);

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.title,
    required this.label,
    required this.action,
    required this.message,
    required this.required,
    required this.maxLength,
  });

  final String title;
  final String label;
  final String action;
  final String? message;
  final bool required;
  final int maxLength;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _form = GlobalKey<FormState>();
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState?.validate() ?? false) Navigator.of(context).pop(_text.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.message case final message?) ...[
              Text(message, style: const TextStyle(fontSize: 12.5)),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _text,
              autofocus: true,
              maxLines: 3,
              minLines: 2,
              maxLength: widget.maxLength,
              decoration: InputDecoration(labelText: widget.label),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty && !widget.required) return null;
                return text.length < 3 ? 'Escribe al menos 3 caracteres.' : null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        TextButton(onPressed: _submit, child: Text(widget.action)),
      ],
    );
  }
}

/// Fila de etiqueta y valor en las tarjetas de la consola.
class AdminInfoCard extends StatelessWidget {
  const AdminInfoCard({super.key, required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) => NexusCard(
    child: Column(
      children: [
        for (final (index, (label, value)) in rows.indexed) ...[
          if (index > 0) const Divider(color: NexusColors.border, height: 1),
          NexusSpecRow(label, value),
        ],
      ],
    ),
  );
}
