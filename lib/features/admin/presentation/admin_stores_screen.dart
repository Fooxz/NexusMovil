import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/nexus_theme.dart';
import '../../../widgets/nexus_empty_state.dart';
import '../../../widgets/nexus_error_state.dart';
import '../../../widgets/nexus_loading.dart';
import '../../../widgets/nexus_page.dart';
import '../../../widgets/nexus_widgets.dart';
import '../../account/domain/account_models.dart';
import '../../account/presentation/staff_account_screen.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../admin_providers.dart';
import '../domain/admin_models.dart';
import 'admin_store_form_screen.dart';
import 'admin_store_screen.dart';

/// Pestaña TIENDAS del administrador: buscar tiendas, crear una verificada
/// con su cuenta y abrir su detalle.
class AdminStoresScreen extends ConsumerStatefulWidget {
  const AdminStoresScreen({super.key});

  @override
  ConsumerState<AdminStoresScreen> createState() => _AdminStoresScreenState();
}

class _AdminStoresScreenState extends ConsumerState<AdminStoresScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  var _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final stores = ref.watch(adminStoresProvider(_query));

    return NexusPage(
      title: 'TIENDAS',
      showCart: false,
      children: [
        NexusPrimaryButton(
          label: 'CREAR TIENDA',
          icon: Icons.add_business_outlined,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const AdminStoreFormScreen.create()),
          ),
        ),
        const SizedBox(height: 12),
        NexusTextField(
          hint: 'Buscar por nombre, razón social o NIT',
          prefixIcon: Icons.search,
          controller: _search,
          onChanged: _onSearch,
        ),
        const SizedBox(height: 12),
        stores.when(
          loading: () => const NexusLoading(),
          error: (error, _) => NexusErrorState(
            message: 'No se pudieron cargar las tiendas.\n${AuthErrorBanner.messageFor(error)}',
            onRetry: () => ref.invalidate(adminStoresProvider(_query)),
          ),
          data: (stores) => stores.isEmpty
              ? const NexusEmptyState(message: 'No hay tiendas con esa búsqueda.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [for (final store in stores) _StoreTile(key: ValueKey(store.id), store: store)],
                ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _StoreTile extends StatelessWidget {
  const _StoreTile({super.key, required this.store});

  final AdminStore store;

  @override
  Widget build(BuildContext context) {
    final active = store.status == StoreStatus.active;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => AdminStoreScreen(storeId: store.id)),
        ),
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
                    NexusTag(storeStatusLabel(store.status), color: active ? NexusColors.green : NexusColors.pink),
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
                  style: TextStyle(
                    fontSize: 11,
                    color: store.hasAccount ? NexusColors.text : NexusColors.textFaint,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
