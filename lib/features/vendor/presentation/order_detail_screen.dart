import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/format_price.dart';
import '../../../theme/nexus_theme.dart';
import '../../../widgets/nexus_error_state.dart';
import '../../../widgets/nexus_loading.dart';
import '../../../widgets/nexus_page.dart';
import '../../../widgets/nexus_widgets.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../domain/vendor_models.dart';
import '../vendor_providers.dart';
import 'vendor_widgets.dart';

/// Detalle de un pedido de la tienda: qué despachar, a quién y adónde, cuánto
/// recibe la tienda y el historial. Las acciones son las que permite el estado
/// actual (RN-029); rechazar, cancelar, devolver y reportar piden el motivo, y
/// enviar pide la transportadora y la guía.
class VendorOrderDetailScreen extends ConsumerWidget {
  const VendorOrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  Future<void> _change(BuildContext context, WidgetRef ref, VendorOrderStatus status) async {
    String? note;
    String? carrier;
    String? tracking;
    if (status.needsShipping) {
      final shipping = await showDialog<(String, String)>(context: context, builder: (_) => const _ShippingDialog());
      if (shipping == null) return;
      (carrier, tracking) = shipping;
    } else if (status.needsNote) {
      note = await showDialog<String>(context: context, builder: (_) => _NoteDialog(status: status));
      if (note == null) return;
    }
    if (!context.mounted) return;
    final updated = await ref
        .read(orderActionControllerProvider.notifier)
        .change(orderId, status, note: note, carrier: carrier, trackingNumber: tracking);
    if (updated != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pedido ${updated.order.orderNumber}: ${updated.order.status.label.toLowerCase()}.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(vendorOrderDetailProvider(orderId));
    final action = ref.watch(orderActionControllerProvider);

    return NexusPage(
      title: switch (detail) {
        AsyncValue(value: final data?) => 'PEDIDO ${data.order.orderNumber}',
        _ => 'PEDIDO',
      },
      showBack: true,
      showCart: false,
      children: [
        switch (detail) {
          AsyncValue(value: final data?) => _Detail(
            data: data,
            busy: action.isLoading,
            error: action.error,
            onChange: (status) => _change(context, ref, status),
          ),
          AsyncValue(:final error?) => NexusErrorState(
            message: 'No se pudo cargar el pedido.\n${AuthErrorBanner.messageFor(error)}',
            onRetry: () => ref.invalidate(vendorOrderDetailProvider(orderId)),
          ),
          _ => const NexusLoading(),
        },
      ],
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.data, required this.busy, required this.error, required this.onChange});

  final VendorOrderDetail data;
  final bool busy;
  final Object? error;
  final ValueChanged<VendorOrderStatus> onChange;

  @override
  Widget build(BuildContext context) {
    final order = data.order;
    final address = data.shippingAddress;
    final contact = data.contact;
    final forward = data.nextStatuses.where((s) => s.isForward).toList();
    final others = data.nextStatuses.where((s) => !s.isForward).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            OrderStatusTag(order.status),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Pagado el ${formatDateTime(order.createdAt)}',
                style: const TextStyle(fontSize: 11, color: NexusColors.textDim),
              ),
            ),
          ],
        ),
        if (data.statusNote case final note?)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Motivo: $note', style: const TextStyle(fontSize: 12, color: NexusColors.pink)),
          ),
        if (order.hasBackorders)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Algunas unidades ya no estaban en stock cuando se aprobó el pago. Confirma si puedes '
              'conseguirlas o rechaza el pedido.',
              style: TextStyle(fontSize: 12, color: NexusColors.pink),
            ),
          ),
        if (error case final error?) ...[
          const SizedBox(height: 10),
          AuthErrorBanner(error),
        ],
        if (data.nextStatuses.isNotEmpty) ...[
          const VendorSectionTitle('ACCIONES'),
          for (final status in forward)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: NexusPrimaryButton(
                label: status.actionLabel.toUpperCase(),
                loading: busy,
                onPressed: () => onChange(status),
              ),
            ),
          for (final status in others)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: NexusOutlineButton(
                label: status.actionLabel,
                color: NexusColors.pink,
                onPressed: busy ? null : () => onChange(status),
              ),
            ),
        ],
        const VendorSectionTitle('PRODUCTOS'),
        NexusCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 6),
              for (final item in data.items) ...[
                NexusSpecRow('${item.quantity} × ${item.productName}', formatPrice(item.lineTotalCents)),
                if (item.backorderedUnits > 0)
                  Text(
                    'Faltaban ${item.backorderedUnits} en stock al pagar',
                    style: const TextStyle(fontSize: 10.5, color: NexusColors.pink),
                  ),
              ],
              const Divider(color: NexusColors.border, height: 14),
              NexusSpecRow('Pagó el cliente (IVA incluido)', formatPrice(order.subtotalCents)),
              NexusSpecRow('Comisión de NEXUS', '− ${formatPrice(order.commissionCents)}',
                  valueColor: NexusColors.textDim),
              NexusSpecRow('Recibes', formatPrice(order.netCents), valueColor: NexusColors.cyan),
              const SizedBox(height: 4),
            ],
          ),
        ),
        const VendorSectionTitle('ENTREGA'),
        NexusCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 6),
              _Line('Recibe', address.recipientName),
              _Line('Teléfono', address.phone),
              _Line('Dirección', [address.addressLine, ?address.details].join(' · ')),
              _Line('Ciudad', '${address.city} (${address.department})'),
              if (order.carrier case final carrier?) _Line('Transportadora', carrier),
              if (order.trackingNumber case final tracking?) _Line('Guía', tracking),
              const SizedBox(height: 6),
            ],
          ),
        ),
        const VendorSectionTitle('CLIENTE Y FACTURACIÓN'),
        NexusCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 6),
              _Line('Nombre', contact.fullName),
              _Line('Documento', '${contact.documentType} ${contact.documentNumber}'),
              _Line('Correo', contact.email),
              _Line('Teléfono', contact.phone),
              const SizedBox(height: 6),
            ],
          ),
        ),
        const VendorSectionTitle('HISTORIAL'),
        for (final change in data.history.reversed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3, right: 10),
                  child: Icon(Icons.circle, size: 9, color: statusColor(change.toStatus)),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(change.toStatus.label,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: NexusColors.text)),
                      Text(
                        [formatDateTime(change.createdAt), ?change.actorName].join(' · '),
                        style: const TextStyle(fontSize: 10.5, color: NexusColors.textDim),
                      ),
                      if (change.note case final note?)
                        Text(note, style: const TextStyle(fontSize: 11.5, color: NexusColors.text)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(label, style: const TextStyle(fontSize: 11, color: NexusColors.textDim)),
          ),
          Expanded(
            child: SelectableText(value, style: const TextStyle(fontSize: 12, color: NexusColors.text)),
          ),
        ],
      ),
    );
  }
}

/// Motivo para rechazar, cancelar, devolver o reportar una incidencia.
class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.status});

  final VendorOrderStatus status;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final _form = GlobalKey<FormState>();
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rejecting = widget.status == VendorOrderStatus.rejected || widget.status == VendorOrderStatus.cancelled;
    return AlertDialog(
      title: Text(widget.status.actionLabel),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (rejecting)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text(
                  'Las unidades vuelven a tu stock. El reembolso al cliente lo gestiona NEXUS.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            TextFormField(
              controller: _note,
              autofocus: true,
              maxLength: 300,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Motivo'),
              validator: (value) =>
                  (value?.trim().length ?? 0) < 3 ? 'Escribe el motivo (al menos 3 caracteres).' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Volver')),
        TextButton(
          onPressed: () {
            if (_form.currentState!.validate()) Navigator.of(context).pop(_note.text.trim());
          },
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}

/// Transportadora y número de guía para marcar el pedido como enviado.
class _ShippingDialog extends StatefulWidget {
  const _ShippingDialog();

  @override
  State<_ShippingDialog> createState() => _ShippingDialogState();
}

class _ShippingDialogState extends State<_ShippingDialog> {
  final _form = GlobalKey<FormState>();
  final _carrier = TextEditingController();
  final _tracking = TextEditingController();

  @override
  void dispose() {
    _carrier.dispose();
    _tracking.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Marcar como enviado'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _carrier,
              autofocus: true,
              maxLength: 60,
              decoration: const InputDecoration(labelText: 'Transportadora', hintText: 'Servientrega, Coordinadora…'),
              validator: (value) => (value?.trim().length ?? 0) < 2 ? 'Escribe la transportadora.' : null,
            ),
            TextFormField(
              controller: _tracking,
              maxLength: 60,
              decoration: const InputDecoration(labelText: 'Número de guía'),
              validator: (value) => (value?.trim().length ?? 0) < 3 ? 'Escribe el número de guía.' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Volver')),
        TextButton(
          onPressed: () {
            if (_form.currentState!.validate()) {
              Navigator.of(context).pop((_carrier.text.trim(), _tracking.text.trim()));
            }
          },
          child: const Text('Marcar como enviado'),
        ),
      ],
    );
  }
}
