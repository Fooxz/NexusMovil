import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/format_price.dart';
import '../../../theme/nexus_theme.dart';
import '../../../widgets/nexus_widgets.dart';
import '../checkout_providers.dart';
import '../domain/checkout_models.dart';

/// Resultado del pago: la orden si se aprobó, la espera si sigue pendiente o
/// el reintento si la pasarela no cobró (RF-059).
class PaymentResultView extends ConsumerWidget {
  const PaymentResultView({super.key, required this.flow});

  final CheckoutFlow flow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(checkoutControllerProvider.notifier);
    final result = flow.result;

    if (result == null) {
      return _Outcome(
        icon: Icons.wifi_off,
        color: NexusColors.pink,
        title: 'No pudimos consultar tu pago',
        message: '${flow.failure?.userMessage ?? ''}\n'
            'Si ya pagaste, tu pago no se pierde: consúltalo de nuevo en un momento.',
        actions: [
          NexusPrimaryButton(label: 'Consultar de nuevo', onPressed: controller.verify),
        ],
      );
    }

    if (result.status == PaymentStatus.approved && result.order != null) {
      return _ApprovedOrder(order: result.order!);
    }

    if (result.status.isRejected) {
      return _Outcome(
        icon: Icons.cancel_outlined,
        color: NexusColors.pink,
        title: 'El pago no se aprobó',
        message: 'No se hizo ningún cobro. Puedes intentarlo de nuevo con otro '
            'medio de pago; tu carrito sigue guardado.',
        actions: [
          NexusPrimaryButton(label: 'Intentar de nuevo', onPressed: controller.retry),
          const SizedBox(height: 10),
          NexusOutlineButton(
            label: 'Volver al carrito',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      );
    }

    // Pendiente: con transacción, Wompi aún confirma (PSE, Nequi); sin ella,
    // el cliente cerró el pago o el aviso no ha llegado.
    final inProgress = result.transactionId != null;
    return _Outcome(
      icon: Icons.hourglass_top,
      color: NexusColors.cyan,
      title: inProgress ? 'Tu pago está en proceso' : 'Aún no recibimos tu pago',
      message: inProgress
          ? 'Wompi todavía no confirma el pago. Suele tardar unos minutos; '
                'cuando se apruebe crearemos tu orden.'
          : 'Si cerraste el pago sin terminar, puedes intentarlo de nuevo. Si ya '
                'pagaste, consulta otra vez en un momento.',
      actions: [
        NexusPrimaryButton(
          label: inProgress ? 'Consultar de nuevo' : 'Ya pagué, consultar',
          onPressed: controller.verify,
        ),
        if (!inProgress) ...[
          const SizedBox(height: 10),
          NexusOutlineButton(label: 'Intentar de nuevo', onPressed: controller.retry),
        ],
      ],
    );
  }
}

class _Outcome extends StatelessWidget {
  const _Outcome({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    required this.actions,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Icon(icon, size: 56, color: color),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          message.trim(),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12.5, color: NexusColors.textDim),
        ),
        const SizedBox(height: 24),
        ...actions,
        const SizedBox(height: 20),
      ],
    );
  }
}

/// Pago aprobado: número de orden y lo que despacha cada proveedor.
class _ApprovedOrder extends StatelessWidget {
  const _ApprovedOrder({required this.order});

  final PlacedOrder order;

  @override
  Widget build(BuildContext context) {
    final shipments = order.subOrders.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        const Icon(Icons.check_circle_outline, size: 56, color: NexusColors.green),
        const SizedBox(height: 14),
        const Text(
          '¡Pago aprobado!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        const SizedBox(height: 6),
        Text(
          'Orden ${order.number}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: NexusColors.cyan),
        ),
        const SizedBox(height: 8),
        Text(
          shipments == 1
              ? 'El proveedor confirmará y despachará tu pedido.'
              : 'Tu pedido llegará en $shipments envíos: cada proveedor confirma '
                    'y despacha su parte.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12.5, color: NexusColors.textDim),
        ),
        const SizedBox(height: 18),
        for (final subOrder in order.subOrders)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: NexusCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    subOrder.providerName.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                      color: NexusColors.textDim,
                    ),
                  ),
                  for (final item in subOrder.items)
                    NexusSpecRow(
                      '${item.quantity} × ${item.productName}',
                      formatPrice(item.lineTotalCents),
                    ),
                  NexusSpecRow(
                    'Subtotal',
                    formatPrice(subOrder.subtotalCents),
                    valueColor: NexusColors.cyan,
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        if (order.hasBackorders)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              'Algunas unidades se agotaron mientras pagabas. El proveedor te '
              'contactará para entregarlas o devolverte ese valor.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: NexusColors.pink),
            ),
          ),
        NexusSpecRow('Total pagado', formatPrice(order.totalCents), valueColor: NexusColors.cyan),
        const SizedBox(height: 20),
        NexusPrimaryButton(
          label: 'Seguir comprando',
          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
