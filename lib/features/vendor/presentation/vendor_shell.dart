import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/nexus_theme.dart';
import '../../../widgets/lazy_indexed_stack.dart';
import '../../../widgets/nexus_menu_scope.dart';
import '../../account/account_providers.dart';
import '../../account/presentation/staff_account_screen.dart';
import '../../catalog/presentation/catalog_screen.dart';
import '../../provider_portal/presentation/my_offers_screen.dart';
import '../domain/vendor_models.dart';
import '../vendor_providers.dart';
import 'inventory_screen.dart';
import 'orders_screen.dart';
import 'vendor_dashboard_screen.dart';

/// Secciones del panel de la tienda (fase 1). Ventas y liquidaciones,
/// atención al cliente, perfil comercial y notificaciones llegan después.
enum VendorSection {
  summary('Resumen', Icons.space_dashboard_outlined),
  products('Productos', Icons.inventory_2_outlined),
  inventory('Inventario', Icons.warehouse_outlined),
  orders('Pedidos', Icons.local_shipping_outlined),
  catalog('Catálogo general', Icons.grid_view_outlined),
  account('Mi cuenta', Icons.person_outline);

  const VendorSection(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Cambia de sección desde las pantallas del panel (por ejemplo, el resumen
/// abre los pedidos nuevos).
class VendorShellScope extends InheritedWidget {
  const VendorShellScope({super.key, required this.select, required super.child});

  final void Function(VendorSection section) select;

  static VendorShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<VendorShellScope>();

  @override
  bool updateShouldNotify(VendorShellScope oldWidget) => select != oldWidget.select;
}

/// Panel de la tienda con menú lateral. Cada pantalla conserva su estado al
/// cambiar de sección; "atrás" vuelve al resumen antes de salir.
class VendorShell extends ConsumerStatefulWidget {
  const VendorShell({super.key});

  @override
  ConsumerState<VendorShell> createState() => _VendorShellState();
}

class _VendorShellState extends ConsumerState<VendorShell> {
  final _scaffold = GlobalKey<ScaffoldState>();
  var _section = VendorSection.summary;

  void _select(VendorSection section) {
    _scaffold.currentState?.closeDrawer();
    if (section != _section) setState(() => _section = section);
  }

  void _openMenu() => _scaffold.currentState?.openDrawer();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _section == VendorSection.summary,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) setState(() => _section = VendorSection.summary);
      },
      child: VendorShellScope(
        select: _select,
        child: NexusMenuScope(
          openMenu: _openMenu,
          child: Scaffold(
            key: _scaffold,
            backgroundColor: NexusColors.bg,
            drawer: _VendorDrawer(selected: _section, onSelect: _select),
            body: LazyIndexedStack(
              index: _section.index,
              children: const [
                VendorDashboardScreen(),
                MyOffersScreen(),
                InventoryScreen(),
                VendorOrdersScreen(),
                CatalogScreen(),
                StaffAccountScreen(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VendorDrawer extends ConsumerWidget {
  const _VendorDrawer({required this.selected, required this.onSelect});

  final VendorSection selected;
  final ValueChanged<VendorSection> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(accountProvider.select((account) => account.value?.store));
    // Pedidos que esperan respuesta de la tienda, junto a "Pedidos".
    final pending = ref.watch(
      vendorDashboardProvider.select(
        (dashboard) => dashboard.value?.ordersIn(VendorOrderStatus.pending) ?? 0,
      ),
    );

    return Drawer(
      backgroundColor: NexusColors.bgAlt,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PANEL DE LA TIENDA',
                    style: TextStyle(fontSize: 10, letterSpacing: 0.8, color: NexusColors.textDim),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    store?.displayName ?? 'Mi tienda',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: NexusColors.text),
                  ),
                ],
              ),
            ),
            const Divider(color: NexusColors.border, height: 1),
            const SizedBox(height: 8),
            for (final section in VendorSection.values)
              ListTile(
                leading: Icon(
                  section.icon,
                  color: section == selected ? NexusColors.cyan : NexusColors.textDim,
                ),
                title: Text(
                  section.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: section == selected ? FontWeight.bold : FontWeight.normal,
                    color: section == selected ? NexusColors.cyan : NexusColors.text,
                  ),
                ),
                trailing: section == VendorSection.orders && pending > 0
                    ? Badge(label: Text('$pending'), backgroundColor: NexusColors.pink)
                    : null,
                selected: section == selected,
                onTap: () => onSelect(section),
              ),
          ],
        ),
      ),
    );
  }
}
