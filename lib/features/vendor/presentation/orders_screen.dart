import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/nexus_empty_state.dart';
import '../../../widgets/nexus_error_state.dart';
import '../../../widgets/nexus_loading.dart';
import '../../../widgets/nexus_page.dart';
import '../../../widgets/nexus_widgets.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../domain/vendor_models.dart';
import '../vendor_providers.dart';
import 'order_detail_screen.dart';
import 'vendor_widgets.dart';

/// Pedidos de la tienda (RF-063): filtro por estado, búsqueda por número o
/// cliente y el detalle para operarlos.
class VendorOrdersScreen extends ConsumerStatefulWidget {
  const VendorOrdersScreen({super.key});

  static const filters = <(String, VendorOrderStatus?)>[
    ('Todos', null),
    ('Nuevos', VendorOrderStatus.pending),
    ('Confirmados', VendorOrderStatus.confirmed),
    ('Preparando', VendorOrderStatus.preparing),
    ('Enviados', VendorOrderStatus.shipped),
    ('Entregados', VendorOrderStatus.delivered),
    ('Con incidencia', VendorOrderStatus.incident),
    ('Rechazados', VendorOrderStatus.rejected),
    ('Cancelados', VendorOrderStatus.cancelled),
    ('Devueltos', VendorOrderStatus.returned),
  ];

  @override
  ConsumerState<VendorOrdersScreen> createState() => _VendorOrdersScreenState();
}

class _VendorOrdersScreenState extends ConsumerState<VendorOrdersScreen> {
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
      () => ref.read(vendorOrdersQueryProvider.notifier).setSearch(text),
    );
  }

  Future<void> _loadMore() async {
    try {
      await ref.read(vendorOrdersProvider.notifier).loadMore();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AuthErrorBanner.messageFor(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(vendorOrdersQueryProvider);
    final orders = ref.watch(vendorOrdersProvider);

    return NexusPage(
      title: 'PEDIDOS',
      showCart: false,
      children: [
        NexusTextField(
          hint: 'Buscar por número de pedido o cliente',
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
                    onSelected: (_) => ref.read(vendorOrdersQueryProvider.notifier).setStatus(status),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        switch (orders) {
          AsyncValue(value: final page?) when page.items.isEmpty => NexusEmptyState(
            message: query.status == null && query.search.isEmpty
                ? 'Todavía no tienes pedidos. Cuando un cliente compre uno de tus productos, aparecerá aquí.'
                : 'No hay pedidos con ese filtro.',
          ),
          AsyncValue(value: final page?) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                page.total == 1 ? '1 pedido' : '${page.total} pedidos',
                style: const TextStyle(fontSize: 11, color: Colors.white54),
              ),
              const SizedBox(height: 8),
              for (final order in page.items)
                VendorOrderTile(
                  order: order,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => VendorOrderDetailScreen(orderId: order.id)),
                  ),
                ),
              if (page.hasMoreWith(VendorOrdersController.pageSize))
                NexusOutlineButton(
                  label: page.loadingMore ? 'Cargando…' : 'Ver más',
                  onPressed: page.loadingMore ? null : _loadMore,
                ),
              const SizedBox(height: 20),
            ],
          ),
          AsyncValue(:final error?) => NexusErrorState(
            message: 'No se pudieron cargar los pedidos.\n${AuthErrorBanner.messageFor(error)}',
            onRetry: () => ref.invalidate(vendorOrdersProvider),
          ),
          _ => const NexusLoading(),
        },
      ],
    );
  }
}
