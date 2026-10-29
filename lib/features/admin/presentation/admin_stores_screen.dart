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
import '../../account/domain/account_models.dart';
import '../../account/presentation/staff_account_screen.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../admin_console_providers.dart';
import '../domain/admin_console_models.dart';
import 'admin_store_form_screen.dart';
import 'admin_store_screen.dart';
import 'admin_widgets.dart';

/// Tiendas: buscar, filtrar por estado, ordenar por ventas o desempeño, crear
/// una verificada con su cuenta y abrir su ficha.
class AdminStoresScreen extends ConsumerStatefulWidget {
  const AdminStoresScreen({super.key});

  @override
  ConsumerState<AdminStoresScreen> createState() => _AdminStoresScreenState();
}

class _AdminStoresScreenState extends ConsumerState<AdminStoresScreen> {
  late final _search = TextEditingController(text: ref.read(adminProvidersQueryProvider).search);
  Timer? _debounce;

  static const _statuses = [
    StoreStatus.active,
    StoreStatus.pending,
    StoreStatus.suspended,
    StoreStatus.blocked,
    StoreStatus.deactivated,
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) ref.read(adminProvidersQueryProvider.notifier).setSearch(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(adminProvidersQueryProvider);
    final stores = ref.watch(adminProvidersProvider);

    return NexusPage(
      title: 'TIENDAS',
      showCart: false,
      children: [
        NexusPrimaryButton(
          label: 'CREAR TIENDA',
          icon: Icons.add_business_outlined,
          onPressed: () =>
              Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AdminStoreFormScreen.create())),
        ),
        const SizedBox(height: 12),
        NexusTextField(
          hint: 'Buscar por nombre, razón social o NIT',
          prefixIcon: Icons.search,
          controller: _search,
          onChanged: _onSearch,
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final status in [null, ..._statuses])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(status == null ? 'Todas' : storeStatusLabel(status)),
                    selected: query.status == status,
                    onSelected: (_) => ref.read(adminProvidersQueryProvider.notifier).setStatus(status),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Text('Ordenar por', style: TextStyle(fontSize: 11.5, color: NexusColors.textDim)),
            const SizedBox(width: 10),
            Flexible(
              child: DropdownButton<ProviderSort>(
                isExpanded: true,
                value: query.sort,
                dropdownColor: NexusColors.bgAlt,
                underline: const SizedBox.shrink(),
                style: const TextStyle(fontSize: 12.5, color: NexusColors.text),
                items: [for (final sort in ProviderSort.values) DropdownMenuItem(value: sort, child: Text(sort.label))],
                onChanged: (sort) {
                  if (sort != null) ref.read(adminProvidersQueryProvider.notifier).setSort(sort);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        stores.when(
          loading: () => const NexusLoading(),
          error: (error, _) => NexusErrorState(
            message: 'No se pudieron cargar las tiendas.\n${AuthErrorBanner.messageFor(error)}',
            onRetry: () => ref.invalidate(adminProvidersProvider),
          ),
          data: (rows) => rows.isEmpty
              ? const NexusEmptyState(message: 'No hay tiendas con esos filtros.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [for (final row in rows) _StoreTile(key: ValueKey(row.store.id), row: row)],
                ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _StoreTile extends StatelessWidget {
  const _StoreTile({super.key, required this.row});

  final AdminProviderRow row;

  @override
  Widget build(BuildContext context) {
    final store = row.store;
    final metrics = row.metrics;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () =>
            Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AdminStoreScreen(storeId: store.id))),
        child: NexusCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        store.displayName,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    NexusTag(storeStatusLabel(store.status), color: storeStatusColor(store.status)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${store.legalName} · NIT ${store.taxId}',
                  style: const TextStyle(fontSize: 11, color: NexusColors.textDim),
                ),
                const SizedBox(height: 2),
                Text(
                  store.accountEmail ?? 'Sin cuenta',
                  style: TextStyle(fontSize: 11, color: store.hasAccount ? NexusColors.text : NexusColors.textFaint),
                ),
                const SizedBox(height: 8),
                Text(
                  [
                    'Ventas 30 días: ${formatPrice(metrics.sales30dCents)}',
                    '${store.publishedOffers} publicadas',
                    'Entregas cumplidas: ${percentLabel(metrics.deliveredRate)}',
                    if (metrics.openOrders > 0) '${metrics.openOrders} pedidos abiertos',
                    if (metrics.warnings > 0) '${metrics.warnings} advertencias',
                  ].join(' · '),
                  style: const TextStyle(fontSize: 11, color: NexusColors.textDim),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
