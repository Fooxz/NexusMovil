import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/format_price.dart';
import '../../../theme/nexus_theme.dart';
import '../../../widgets/nexus_error_state.dart';
import '../../../widgets/nexus_loading.dart';
import '../../../widgets/nexus_page.dart';
import '../../account/domain/account_models.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../../catalog/presentation/product_visuals.dart';
import '../../provider_portal/domain/portal_models.dart';
import '../../vendor/domain/vendor_models.dart';
import '../../vendor/presentation/vendor_widgets.dart';
import '../admin_console_providers.dart';
import '../domain/admin_console_models.dart';
import 'admin_charts.dart';
import 'admin_shell.dart';
import 'admin_widgets.dart';

/// Resumen global de NEXUS: alertas, ventas e ingresos, ventas diarias,
/// pedidos, usuarios, catálogo y categorías más vendidas. Las alertas y los
/// indicadores abren su sección ya filtrada.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(adminDashboardProvider);

    void open(AdminSection section) => AdminShellScope.maybeOf(context)?.select(section);

    void openOffers({OfferModeration? moderation, bool anyFlag = false}) {
      ref.read(adminOffersQueryProvider.notifier)
        ..setModeration(moderation)
        ..setFlag(null, anyFlag: anyFlag);
      open(AdminSection.moderation);
    }

    void openOrders(VendorOrderStatus? status) {
      ref.read(adminOrdersQueryProvider.notifier).setStatus(status);
      open(AdminSection.orders);
    }

    void openStores(StoreStatus? status) {
      ref.read(adminProvidersQueryProvider.notifier).setStatus(status);
      open(AdminSection.stores);
    }

    return NexusPage(
      title: 'RESUMEN',
      showCart: false,
      children: [
        switch (dashboard) {
          AsyncValue(value: final data?) => _Content(
            data: data,
            refreshing: dashboard.isLoading,
            onRefresh: () => ref.invalidate(adminDashboardProvider),
            onAlert: (kind) => switch (kind) {
              AdminAlertKind.offersReview => openOffers(moderation: OfferModeration.review),
              AdminAlertKind.ordersIncident => openOrders(VendorOrderStatus.incident),
              AdminAlertKind.ordersStale => openOrders(VendorOrderStatus.pending),
              AdminAlertKind.providersPending => openStores(StoreStatus.pending),
              AdminAlertKind.newProviders => openStores(null),
              _ => null,
            },
            onFlagged: () => openOffers(anyFlag: true),
            onOrders: openOrders,
            onStores: openStores,
          ),
          AsyncValue(:final error?) => NexusErrorState(
            message: 'No se pudo cargar el resumen.\n${AuthErrorBanner.messageFor(error)}',
            onRetry: () => ref.invalidate(adminDashboardProvider),
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
    required this.onAlert,
    required this.onFlagged,
    required this.onOrders,
    required this.onStores,
  });

  final AdminDashboard data;
  final bool refreshing;
  final VoidCallback onRefresh;
  final void Function(AdminAlertKind kind) onAlert;
  final VoidCallback onFlagged;
  final ValueChanged<VendorOrderStatus?> onOrders;
  final ValueChanged<StoreStatus?> onStores;

  static bool _opens(AdminAlertKind kind) =>
      kind != AdminAlertKind.paymentsError &&
      kind != AdminAlertKind.paymentEventsUnknown &&
      kind != AdminAlertKind.assistantUnavailable;

  static IconData _icon(AdminAlertKind kind) => switch (kind) {
    AdminAlertKind.offersReview => Icons.fact_check_outlined,
    AdminAlertKind.ordersIncident => Icons.report_problem_outlined,
    AdminAlertKind.ordersStale => Icons.schedule,
    AdminAlertKind.providersPending || AdminAlertKind.newProviders => Icons.storefront_outlined,
    AdminAlertKind.paymentsError || AdminAlertKind.paymentEventsUnknown => Icons.credit_card_off_outlined,
    AdminAlertKind.assistantUnavailable => Icons.smart_toy_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final otherStores = data.providersByStatus.entries
        .where((entry) => entry.key != 'active' && entry.value > 0)
        .map((entry) => '${entry.value} ${_storeStatusName(entry.key)}')
        .join(' · ');

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
        if (data.alerts.isNotEmpty || data.flaggedOffers > 0) ...[
          const VendorSectionTitle('NECESITA ATENCIÓN'),
          for (final alert in data.alerts)
            _AlertRow(
              icon: _icon(alert.kind),
              color: alert.kind == AdminAlertKind.newProviders ? NexusColors.cyan : NexusColors.pink,
              text: alert.kind.label(alert.count),
              onTap: _opens(alert.kind) ? () => onAlert(alert.kind) : null,
            ),
          if (data.flaggedOffers > 0)
            _AlertRow(
              icon: Icons.flag_outlined,
              color: amber,
              text: data.flaggedOffers == 1
                  ? '1 publicación con alertas de calidad'
                  : '${data.flaggedOffers} publicaciones con alertas de calidad',
              onTap: onFlagged,
            ),
        ],
        const VendorSectionTitle('VENTAS'),
        StatGrid(
          columns: 3,
          tiles: [
            StatTile(
              label: 'Hoy',
              value: formatPrice(data.today.currentCents),
              caption: growthLabel(data.today, 'ayer'),
            ),
            StatTile(
              label: 'Esta semana',
              value: formatPrice(data.week.currentCents),
              caption: growthLabel(data.week, 'la anterior'),
            ),
            StatTile(
              label: 'Este mes',
              value: formatPrice(data.month.currentCents),
              caption: growthLabel(data.month, 'el anterior'),
            ),
          ],
        ),
        StatGrid(
          tiles: [
            StatTile(
              label: 'Comisión del mes',
              value: formatPrice(data.monthCommissionCents),
              caption: 'Ingreso de NEXUS',
              color: NexusColors.cyan,
            ),
            StatTile(
              label: 'Para las tiendas este mes',
              value: formatPrice(data.monthProviderNetCents),
              caption: 'Ventas menos la comisión',
            ),
            StatTile(
              label: 'Ventas totales',
              value: formatPrice(data.totalSalesCents),
              caption: 'Comisión: ${formatPrice(data.totalCommissionCents)}',
            ),
            StatTile(
              label: 'Pedidos totales',
              value: '${data.totalOrders}',
              caption: 'Cada pedido puede tener varias tiendas',
            ),
          ],
        ),
        const VendorSectionTitle('VENTAS DIARIAS'),
        DailySalesChart(series: data.series),
        const VendorSectionTitle('PEDIDOS POR TIENDA'),
        StatGrid(
          columns: 3,
          tiles: [
            StatTile(label: 'En curso', value: '${data.ordersInProgress}', onTap: () => onOrders(null)),
            StatTile(
              label: 'Nuevos',
              value: '${data.ordersPending}',
              color: NexusColors.cyan,
              caption: data.ordersStale > 0 ? '${data.ordersStale} con más de 48 h' : null,
              onTap: () => onOrders(VendorOrderStatus.pending),
            ),
            StatTile(
              label: 'Entregados',
              value: '${data.ordersDelivered}',
              onTap: () => onOrders(VendorOrderStatus.delivered),
            ),
            StatTile(
              label: 'Cancelados',
              value: '${data.ordersCancelled}',
              caption: 'Incluye rechazados',
              onTap: () => onOrders(VendorOrderStatus.cancelled),
            ),
            StatTile(
              label: 'Devueltos',
              value: '${data.ordersReturned}',
              onTap: () => onOrders(VendorOrderStatus.returned),
            ),
            StatTile(
              label: 'Con incidencia',
              value: '${data.ordersIncident}',
              color: data.ordersIncident > 0 ? NexusColors.pink : NexusColors.text,
              onTap: () => onOrders(VendorOrderStatus.incident),
            ),
          ],
        ),
        const VendorSectionTitle('USUARIOS'),
        StatGrid(
          tiles: [
            StatTile(
              label: 'Clientes',
              value: '${data.customers}',
              caption: '${data.activeCustomers} activos y ${data.newCustomers} nuevos en 30 días',
            ),
            StatTile(
              label: 'Tiendas habilitadas',
              value: '${data.providersIn('active')}',
              caption: otherStores.isEmpty ? null : otherStores,
              onTap: () => onStores(null),
            ),
          ],
        ),
        const VendorSectionTitle('CATÁLOGO'),
        StatGrid(
          tiles: [
            StatTile(
              label: 'Productos visibles',
              value: '${data.visibleProducts}',
              caption: 'De ${data.products} fichas',
            ),
            StatTile(label: 'Agotados', value: '${data.outOfStockProducts}', caption: 'Visibles sin unidades'),
            StatTile(
              label: 'Con alertas',
              value: '${data.flaggedOffers}',
              color: data.flaggedOffers > 0 ? amber : NexusColors.text,
              onTap: onFlagged,
            ),
            StatTile(
              label: 'Moderadas',
              value: '${data.hiddenOffers + data.reviewOffers + data.rejectedOffers}',
              caption:
                  '${data.hiddenOffers} ocultas · ${data.reviewOffers} en revisión · ${data.rejectedOffers} rechazadas',
            ),
          ],
        ),
        const VendorSectionTitle('MÁS VENDIDO EN 30 DÍAS'),
        CategoryBars(
          rows: data.topCategories,
          labelFor: (row) => row.category == null ? row.name : ProductVisuals.forCategory(row.category!).categoryLabel,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  static String _storeStatusName(String status) => switch (status) {
    'pending' => 'pendientes',
    'suspended' => 'suspendidas',
    'blocked' => 'bloqueadas',
    'deactivated' => 'desactivadas',
    'rejected' => 'rechazadas',
    _ => status,
  };
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.icon, required this.color, required this.text, this.onTap});

  final IconData icon;
  final Color color;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: NexusColors.card,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: NexusColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(text, style: const TextStyle(fontSize: 12.5, color: NexusColors.text)),
                ),
                if (onTap != null) const Icon(Icons.chevron_right, size: 18, color: NexusColors.textFaint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
