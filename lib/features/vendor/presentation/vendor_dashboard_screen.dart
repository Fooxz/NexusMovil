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
import 'order_detail_screen.dart';
import 'vendor_shell.dart';
import 'vendor_widgets.dart';

/// Resumen del negocio: ventas, pedidos por estado, inventario, dinero del
/// mes, alertas y últimos pedidos. Cada indicador abre su sección.
class VendorDashboardScreen extends ConsumerWidget {
  const VendorDashboardScreen({super.key});

  void _openOrders(BuildContext context, WidgetRef ref, VendorOrderStatus? status) {
    ref.read(vendorOrdersQueryProvider.notifier).setStatus(status);
    VendorShellScope.maybeOf(context)?.select(VendorSection.orders);
  }

  void _openInventory(BuildContext context, WidgetRef ref, StockAlert? alert) {
    ref.read(inventoryQueryProvider.notifier).setAlert(alert);
    VendorShellScope.maybeOf(context)?.select(VendorSection.inventory);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(vendorDashboardProvider);

    return NexusPage(
      title: 'RESUMEN',
      showCart: false,
      children: [
        switch (dashboard) {
          AsyncValue(value: final data?) => _Content(
            data: data,
            refreshing: dashboard.isLoading,
            onRefresh: () => ref.invalidate(vendorDashboardProvider),
            onOrders: (status) => _openOrders(context, ref, status),
            onInventory: (alert) => _openInventory(context, ref, alert),
          ),
          AsyncValue(:final error?) => NexusErrorState(
            message: 'No se pudo cargar el resumen.\n${AuthErrorBanner.messageFor(error)}',
            onRetry: () => ref.invalidate(vendorDashboardProvider),
          ),
          _ => const NexusLoading(),
        },
      ],
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.data,
    required this.refreshing,
    required this.onRefresh,
    required this.onOrders,
    required this.onInventory,
  });

  final VendorDashboard data;
  final bool refreshing;
  final VoidCallback onRefresh;
  final ValueChanged<VendorOrderStatus?> onOrders;
  final ValueChanged<StockAlert?> onInventory;

  @override
  Widget build(BuildContext context) {
    final newOrders = data.ordersIn(VendorOrderStatus.pending);
    final incidents = data.ordersIn(VendorOrderStatus.incident);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: refreshing ? null : onRefresh,
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(refreshing ? 'Actualizando…' : 'Actualizar'),
          ),
        ),
        // Alertas: lo que necesita atención hoy.
        if (newOrders > 0 || incidents > 0 || data.lowStock > 0 || data.outOfStock > 0) ...[
          const VendorSectionTitle('NECESITA TU ATENCIÓN'),
          if (newOrders > 0)
            _Alert(
              icon: Icons.notifications_active_outlined,
              color: NexusColors.cyan,
              text: newOrders == 1 ? '1 pedido nuevo por aceptar' : '$newOrders pedidos nuevos por aceptar',
              onTap: () => onOrders(VendorOrderStatus.pending),
            ),
          if (incidents > 0)
            _Alert(
              icon: Icons.report_problem_outlined,
              color: NexusColors.pink,
              text: incidents == 1 ? '1 pedido con incidencia' : '$incidents pedidos con incidencia',
              onTap: () => onOrders(VendorOrderStatus.incident),
            ),
          if (data.outOfStock > 0)
            _Alert(
              icon: Icons.remove_shopping_cart_outlined,
              color: NexusColors.pink,
              text: data.outOfStock == 1
                  ? '1 producto publicado está agotado'
                  : '${data.outOfStock} productos publicados están agotados',
              onTap: () => onInventory(StockAlert.out),
            ),
          if (data.lowStock > 0)
            _Alert(
              icon: Icons.trending_down,
              color: const Color(0xFFFFC857),
              text: data.lowStock == 1 ? '1 producto con stock bajo' : '${data.lowStock} productos con stock bajo',
              onTap: () => onInventory(StockAlert.low),
            ),
        ],
        const VendorSectionTitle('VENTAS'),
        StatGrid(
          columns: 3,
          tiles: [
            StatTile(label: 'Hoy', value: formatPrice(data.today.currentCents),
                caption: growthLabel(data.today, 'ayer')),
            StatTile(label: 'Esta semana', value: formatPrice(data.week.currentCents),
                caption: growthLabel(data.week, 'la anterior')),
            StatTile(label: 'Este mes', value: formatPrice(data.month.currentCents),
                caption: growthLabel(data.month, 'el anterior')),
          ],
        ),
        const VendorSectionTitle('PEDIDOS'),
        StatGrid(
          columns: 3,
          tiles: [
            for (final status in const [
              VendorOrderStatus.pending,
              VendorOrderStatus.confirmed,
              VendorOrderStatus.preparing,
              VendorOrderStatus.shipped,
              VendorOrderStatus.delivered,
              VendorOrderStatus.cancelled,
            ])
              StatTile(
                label: status == VendorOrderStatus.pending
                    ? 'Nuevos'
                    : status == VendorOrderStatus.cancelled
                    ? 'Cancelados'
                    : status.label,
                value: '${data.ordersIn(status)}',
                color: data.ordersIn(status) > 0 ? statusColor(status) : NexusColors.textDim,
                onTap: () => onOrders(status),
              ),
          ],
        ),
        const VendorSectionTitle('INVENTARIO'),
        StatGrid(
          columns: 3,
          tiles: [
            StatTile(label: 'Publicados', value: '${data.activeOffers}', onTap: () => onInventory(null)),
            StatTile(
              label: 'Stock bajo',
              value: '${data.lowStock}',
              color: data.lowStock > 0 ? const Color(0xFFFFC857) : NexusColors.textDim,
              onTap: () => onInventory(StockAlert.low),
            ),
            StatTile(
              label: 'Agotados',
              value: '${data.outOfStock}',
              color: data.outOfStock > 0 ? NexusColors.pink : NexusColors.textDim,
              onTap: () => onInventory(StockAlert.out),
            ),
          ],
        ),
        const VendorSectionTitle('DINERO DEL MES'),
        NexusCard(
          child: Column(
            children: [
              const SizedBox(height: 4),
              NexusSpecRow('Ingresos brutos', formatPrice(data.grossCents)),
              NexusSpecRow('Comisión de NEXUS', '− ${formatPrice(data.commissionCents)}',
                  valueColor: NexusColors.textDim),
              const Divider(color: NexusColors.border, height: 12),
              NexusSpecRow('Ganancia neta', formatPrice(data.netCents), valueColor: NexusColors.cyan),
              NexusSpecRow('Pendiente de pago (total)', formatPrice(data.pendingPayoutCents)),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'La comisión se calcula sobre el valor sin IVA. Las liquidaciones y los pagos a la tienda '
                  'llegan en la siguiente fase del panel.',
                  style: TextStyle(fontSize: 10.5, color: NexusColors.textFaint),
                ),
              ),
            ],
          ),
        ),
        VendorSectionTitle(
          'ÚLTIMOS PEDIDOS',
          trailing: data.recentOrders.isEmpty
              ? null
              : TextButton(onPressed: () => onOrders(null), child: const Text('Ver todos')),
        ),
        if (data.recentOrders.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Todavía no tienes pedidos. Cuando un cliente compre uno de tus productos, aparecerá aquí.',
              style: TextStyle(fontSize: 12, color: NexusColors.textDim),
            ),
          )
        else
          for (final order in data.recentOrders)
            VendorOrderTile(
              order: order,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => VendorOrderDetailScreen(orderId: order.id)),
              ),
            ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _Alert extends StatelessWidget {
  const _Alert({required this.icon, required this.color, required this.text, required this.onTap});

  final IconData icon;
  final Color color;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: color.withValues(alpha: 0.6)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 10),
                Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5, color: NexusColors.text))),
                const Icon(Icons.chevron_right, size: 18, color: NexusColors.textDim),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
