import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/format_price.dart';
import '../../../theme/nexus_theme.dart';
import '../../../widgets/nexus_error_state.dart';
import '../../../widgets/nexus_loading.dart';
import '../../../widgets/nexus_page.dart';
import '../../../widgets/nexus_widgets.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../../vendor/domain/vendor_models.dart';
import '../../vendor/presentation/vendor_widgets.dart';
import '../admin_console_providers.dart';
import '../domain/admin_console_models.dart';
import 'admin_store_screen.dart';
import 'admin_widgets.dart';

/// Un pedido completo visto por NEXUS: pago, cliente, entrega, la parte de
/// cada tienda con su historial y las observaciones del administrador. El
/// administrador puede intervenir el estado de cada parte, siempre con una
/// observación.
class AdminOrderScreen extends ConsumerWidget {
  const AdminOrderScreen({super.key, required this.orderId});

  final String orderId;

  static String _paymentStatus(String status) => switch (status) {
    'approved' => 'Aprobado',
    'pending' => 'Pendiente',
    'declined' => 'Rechazado',
    'voided' => 'Anulado',
    'error' => 'Con error',
    'abandoned' => 'Abandonado',
    _ => status,
  };

  void _showResult(BuildContext context, WidgetRef ref, Object? result, String done) {
    final error = ref.read(adminConsoleActionProvider).error;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(result != null ? done : AuthErrorBanner.messageFor(error ?? Object()))));
  }

  Future<void> _intervene(BuildContext context, WidgetRef ref, AdminSubOrder sub, VendorOrderStatus status) async {
    final input = status.needsShipping
        ? await showDialog<({String note, String carrier, String tracking})>(
            context: context,
            builder: (_) => const _ShippingDialog(),
          )
        : await showReasonDialog(
            context,
            title: status.actionLabel,
            message: status == VendorOrderStatus.cancelled || status == VendorOrderStatus.rejected
                ? 'Las unidades vuelven al stock de ${sub.providerName}. El reembolso al cliente se gestiona aparte.'
                : 'La observación queda en el historial del pedido.',
            label: 'Observación de NEXUS',
            action: 'Confirmar',
          ).then((note) => note == null ? null : (note: note, carrier: '', tracking: ''));
    if (input == null || !context.mounted) return;
    final result = await ref
        .read(adminConsoleActionProvider.notifier)
        .updateSubOrder(
          orderId,
          sub.detail.order.id,
          status,
          note: input.note,
          carrier: status.needsShipping ? input.carrier : null,
          trackingNumber: status.needsShipping ? input.tracking : null,
        );
    if (context.mounted) _showResult(context, ref, result, 'Pedido de ${sub.providerName}: ${status.label}.');
  }

  Future<void> _addNote(BuildContext context, WidgetRef ref) async {
    final message = await showReasonDialog(
      context,
      title: 'Observación',
      label: 'Qué pasó o qué se hizo',
      action: 'Guardar',
      maxLength: 500,
    );
    if (message == null || !context.mounted) return;
    final result = await ref.read(adminConsoleActionProvider.notifier).addOrderNote(orderId, message);
    if (context.mounted) _showResult(context, ref, result, 'Observación guardada.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(adminOrderDetailProvider(orderId));
    final busy = ref.watch(adminConsoleActionProvider).isLoading;

    return NexusPage(
      title: 'PEDIDO',
      showBack: true,
      showCart: false,
      children: [
        detail.when(
          loading: () => const NexusLoading(),
          error: (error, _) => NexusErrorState(
            message: 'No se pudo cargar el pedido.\n${AuthErrorBanner.messageFor(error)}',
            onRetry: () => ref.invalidate(adminOrderDetailProvider(orderId)),
          ),
          data: (order) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Pedido ${order.number}',
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                '${formatDateTime(order.createdAt)} · ${formatPrice(order.totalCents)}',
                style: const TextStyle(fontSize: 12, color: NexusColors.textDim),
              ),
              const VendorSectionTitle('PAGO'),
              AdminInfoCard(
                rows: [
                  ('ESTADO', _paymentStatus(order.payment.status)),
                  ('MONTO', formatPrice(order.payment.amountCents)),
                  ('MÉTODO', order.payment.method ?? '—'),
                  ('REFERENCIA', order.payment.reference),
                  if (order.payment.transactionId case final id?) ('PAGO EN MERCADO PAGO', id),
                ],
              ),
              const VendorSectionTitle('CLIENTE Y ENTREGA'),
              AdminInfoCard(
                rows: [
                  ('CLIENTE', order.contact.fullName),
                  ('CORREO', order.contact.email),
                  ('TELÉFONO', order.contact.phone),
                  ('DOCUMENTO', '${order.contact.documentType} ${order.contact.documentNumber}'),
                  (
                    'DIRECCIÓN',
                    [
                      order.shippingAddress.addressLine,
                      ?order.shippingAddress.details,
                      '${order.shippingAddress.city}, ${order.shippingAddress.department}',
                    ].join(' · '),
                  ),
                ],
              ),
              for (final sub in order.subOrders)
                _SubOrderCard(sub: sub, busy: busy, onIntervene: (status) => _intervene(context, ref, sub, status)),
              VendorSectionTitle(
                'OBSERVACIONES DE NEXUS',
                trailing: TextButton.icon(
                  onPressed: busy ? null : () => _addNote(context, ref),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Agregar'),
                ),
              ),
              if (order.notes.isEmpty)
                const Text('Sin observaciones.', style: TextStyle(fontSize: 12, color: NexusColors.textDim))
              else
                for (final note in order.notes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: NexusCard(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(note.message, style: const TextStyle(fontSize: 12.5, color: NexusColors.text)),
                            const SizedBox(height: 4),
                            Text(
                              [formatDateTime(note.createdAt), ?note.actorName].join(' · '),
                              style: const TextStyle(fontSize: 10.5, color: NexusColors.textFaint),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }
}

class _SubOrderCard extends StatelessWidget {
  const _SubOrderCard({required this.sub, required this.busy, required this.onIntervene});

  final AdminSubOrder sub;
  final bool busy;
  final ValueChanged<VendorOrderStatus> onIntervene;

  @override
  Widget build(BuildContext context) {
    final detail = sub.detail;
    final order = detail.order;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VendorSectionTitle(sub.providerName.toUpperCase(), trailing: OrderStatusTag(order.status)),
        NexusCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final item in detail.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '${item.quantity} × ${item.productName}'
                            '${item.backorderedUnits > 0 ? ' (${item.backorderedUnits} sin stock al pagar)' : ''}',
                            style: const TextStyle(fontSize: 12, color: NexusColors.text),
                          ),
                        ),
                        Text(
                          formatPrice(item.lineTotalCents),
                          style: const TextStyle(fontSize: 12, color: NexusColors.text),
                        ),
                      ],
                    ),
                  ),
                const Divider(color: NexusColors.border, height: 12),
                Text(
                  'Subtotal ${formatPrice(order.subtotalCents)} · comisión ${formatPrice(order.commissionCents)} · '
                  'tienda ${formatPrice(order.netCents)}',
                  style: const TextStyle(fontSize: 11, color: NexusColors.textDim),
                ),
                if (order.trackingNumber case final tracking?)
                  Text(
                    'Guía: ${order.carrier ?? ''} $tracking',
                    style: const TextStyle(fontSize: 11, color: NexusColors.textDim),
                  ),
                if (detail.statusNote case final note?)
                  Text('Último motivo: $note', style: const TextStyle(fontSize: 11, color: NexusColors.textDim)),
                const SizedBox(height: 8),
                const Text(
                  'HISTORIAL',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: NexusColors.textDim),
                ),
                const SizedBox(height: 4),
                for (final change in detail.history)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      [
                        formatDateTime(change.createdAt),
                        change.toStatus.label,
                        ?change.note,
                        change.actorName ?? 'Sistema',
                      ].join(' · '),
                      style: const TextStyle(fontSize: 11, color: NexusColors.text),
                    ),
                  ),
                InkWell(
                  onTap: () =>
                      Navigator.of(context)
                          .push(MaterialPageRoute<void>(builder: (_) => AdminStoreScreen(storeId: sub.providerId))),
                  child: const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('Ver la tienda ›', style: TextStyle(fontSize: 11.5, color: NexusColors.cyan)),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (sub.adminNextStatuses.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final status in sub.adminNextStatuses)
                OutlinedButton(
                  onPressed: busy ? null : () => onIntervene(status),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: status.isForward ? NexusColors.cyan : NexusColors.pink,
                    side: BorderSide(color: status.isForward ? NexusColors.cyan : NexusColors.pink),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(status.actionLabel, style: const TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Enviar exige la transportadora y la guía, además de la observación.
class _ShippingDialog extends StatefulWidget {
  const _ShippingDialog();

  @override
  State<_ShippingDialog> createState() => _ShippingDialogState();
}

class _ShippingDialogState extends State<_ShippingDialog> {
  final _form = GlobalKey<FormState>();
  final _carrier = TextEditingController();
  final _tracking = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    for (final controller in [_carrier, _tracking, _note]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _required(String? value, int min) =>
      (value?.trim().length ?? 0) < min ? 'Escribe al menos $min caracteres.' : null;

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
              decoration: const InputDecoration(labelText: 'Transportadora'),
              validator: (value) => _required(value, 2),
            ),
            TextFormField(
              controller: _tracking,
              decoration: const InputDecoration(labelText: 'Número de guía'),
              validator: (value) => _required(value, 3),
            ),
            TextFormField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Observación de NEXUS'),
              validator: (value) => _required(value, 3),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        TextButton(
          onPressed: () {
            if (!(_form.currentState?.validate() ?? false)) return;
            Navigator.of(context)
                .pop((note: _note.text.trim(), carrier: _carrier.text.trim(), tracking: _tracking.text.trim()));
          },
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
