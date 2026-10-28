import 'package:flutter/material.dart';

import '../../../core/utils/format_price.dart';
import '../../../theme/nexus_theme.dart';
import '../../../widgets/nexus_widgets.dart';
import '../domain/vendor_models.dart';

/// "28/10/2026 14:05", en la hora del teléfono.
String formatDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
}

/// "+12 % vs. ayer", o null si el periodo anterior no tuvo ventas.
String? growthLabel(SalesPeriod period, String previous) {
  final growth = period.growthPercent;
  if (growth == null) return null;
  final rounded = growth.round();
  return '${rounded > 0 ? '+' : ''}$rounded % vs. $previous';
}

Color statusColor(VendorOrderStatus status) => switch (status) {
  VendorOrderStatus.pending => NexusColors.cyan,
  VendorOrderStatus.confirmed || VendorOrderStatus.preparing => const Color(0xFFFFC857),
  VendorOrderStatus.shipped || VendorOrderStatus.delivered => NexusColors.green,
  VendorOrderStatus.incident ||
  VendorOrderStatus.rejected ||
  VendorOrderStatus.cancelled ||
  VendorOrderStatus.returned => NexusColors.pink,
};

class OrderStatusTag extends StatelessWidget {
  const OrderStatusTag(this.status, {super.key});

  final VendorOrderStatus status;

  @override
  Widget build(BuildContext context) => NexusTag(status.label.toUpperCase(), color: statusColor(status));
}

class VendorSectionTitle extends StatelessWidget {
  const VendorSectionTitle(this.label, {super.key, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
                color: NexusColors.textDim,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Indicador del resumen: un número grande con su etiqueta. Con [onTap] abre
/// la sección correspondiente.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.color = NexusColors.text,
    this.onTap,
  });

  final String label;
  final String value;
  final String? caption;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NexusColors.card,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: NexusColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10.5, color: NexusColors.textDim)),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
                ),
              ),
              if (caption case final caption?) ...[
                const SizedBox(height: 4),
                Text(caption, style: const TextStyle(fontSize: 10, color: NexusColors.textFaint)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Indicadores en filas de [columns].
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.tiles, this.columns = 2});

  final List<Widget> tiles;
  final int columns;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var start = 0; start < tiles.length; start += columns)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = start; i < start + columns; i++) ...[
                  if (i > start) const SizedBox(width: 8),
                  Expanded(child: i < tiles.length ? tiles[i] : const SizedBox.shrink()),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// Fila de un pedido en las listas.
class VendorOrderTile extends StatelessWidget {
  const VendorOrderTile({super.key, required this.order, required this.onTap});

  final VendorOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: NexusColors.card,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: NexusColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Pedido ${order.orderNumber}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: NexusColors.text),
                      ),
                    ),
                    OrderStatusTag(order.status),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    formatDateTime(order.createdAt),
                    ?order.customerName,
                    ?order.city,
                  ].join(' · '),
                  style: const TextStyle(fontSize: 11, color: NexusColors.textDim),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      order.units == 1 ? '1 unidad' : '${order.units} unidades',
                      style: const TextStyle(fontSize: 11, color: NexusColors.textDim),
                    ),
                    const Spacer(),
                    Text(
                      'Recibes ${formatPrice(order.netCents)}',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: NexusColors.cyan),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
