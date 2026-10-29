import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/format_price.dart';
import '../../../theme/nexus_theme.dart';
import '../../../widgets/nexus_empty_state.dart';
import '../../../widgets/nexus_error_state.dart';
import '../../../widgets/nexus_loading.dart';
import '../../../widgets/nexus_page.dart';
import '../../../widgets/nexus_widgets.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../../vendor/presentation/orders_screen.dart';
import '../../vendor/presentation/vendor_widgets.dart';
import '../admin_console_providers.dart';
import '../domain/admin_console_models.dart';
import 'admin_order_screen.dart';

/// Pedidos de todas las tiendas: una fila por tienda de cada pedido, con
/// filtro por estado y búsqueda por número, cliente o tienda.
class AdminOrdersScreen extends ConsumerStatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  ConsumerState<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends ConsumerState<AdminOrdersScreen> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => ref.read(adminOrdersQueryProvider.notifier).setSearch(text),
    );
  }

  Future<void> _loadMore() async {
    try {
      await ref.read(adminOrdersProvider.notifier).loadMore();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AuthErrorBanner.messageFor(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(adminOrdersQueryProvider);
    final orders = ref.watch(adminOrdersProvider);

    return NexusPage(
      title: 'PEDIDOS',
      showCart: false,
      children: [
        NexusTextField(
          hint: 'Buscar por número, cliente o tienda',
          prefixIcon: Icons.search,
          onChanged: _onSearch,
          textInputAction: TextInputAction.search,
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (label, status) in VendorOrdersScreen.filters)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: query.status == status,
                    onSelected: (_) => ref.read(adminOrdersQueryProvider.notifier).setStatus(status),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        switch (orders) {
          AsyncValue(value: final page?) when page.items.isEmpty => NexusEmptyState(
            message: query.status == null && query.search.isEmpty
                ? 'Todavía no hay pedidos en NEXUS.'
                : 'No hay pedidos con ese filtro.',
          ),
          AsyncValue(value: final page?) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                page.total == 1 ? '1 pedido de tienda' : '${page.total} pedidos de tienda',
                style: const TextStyle(fontSize: 11, color: Colors.white54),
              ),
              const SizedBox(height: 8),
              for (final row in page.items) _OrderTile(key: ValueKey(row.order.id), row: row),
              if (page.hasMoreWith(AdminOrdersController.pageSize))
                NexusOutlineButton(
                  label: page.loadingMore ? 'Cargando…' : 'Ver más',
                  onPressed: page.loadingMore ? null : _loadMore,
                ),
              const SizedBox(height: 20),
            ],
          ),
          AsyncValue(:final error?) => NexusErrorState(
            message: 'No se pudieron cargar los pedidos.\n${AuthErrorBanner.messageFor(error)}',
            onRetry: () => ref.invalidate(adminOrdersProvider),
          ),
          _ => const NexusLoading(),
        },
      ],
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({super.key, required this.row});

  final AdminOrderRow row;

  @override
  Widget build(BuildContext context) {
    final order = row.order;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () =>
            Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AdminOrderScreen(orderId: row.orderId))),
        child: NexusCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
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
                const SizedBox(height: 4),
                Text(
                  [row.providerName, ?order.customerName, ?order.city].join(' · '),
                  style: const TextStyle(fontSize: 11, color: NexusColors.textDim),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      formatDateTime(order.createdAt),
                      style: const TextStyle(fontSize: 11, color: NexusColors.textDim),
                    ),
                    const Spacer(),
                    Text(
                      formatPrice(order.subtotalCents),
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: NexusColors.text),
                    ),
                  ],
                ),
                Text(
                  'Comisión NEXUS: ${formatPrice(order.commissionCents)}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 10.5, color: NexusColors.textFaint),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
