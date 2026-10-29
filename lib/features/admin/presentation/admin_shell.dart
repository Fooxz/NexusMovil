import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/nexus_theme.dart';
import '../../../widgets/lazy_indexed_stack.dart';
import '../../../widgets/nexus_menu_scope.dart';
import '../../account/presentation/staff_account_screen.dart';
import '../../catalog/presentation/catalog_screen.dart';
import '../admin_console_providers.dart';
import 'admin_dashboard_screen.dart';
import 'admin_moderation_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_stores_screen.dart';

/// Secciones de la consola del administrador (entrega 1). Finanzas y
/// clientes llegan en la entrega 2.
enum AdminSection {
  summary('Resumen', Icons.space_dashboard_outlined),
  stores('Tiendas', Icons.storefront_outlined),
  moderation('Moderación del catálogo', Icons.fact_check_outlined),
  orders('Pedidos', Icons.local_shipping_outlined),
  catalog('Catálogo general', Icons.grid_view_outlined),
  account('Mi cuenta', Icons.person_outline);

  const AdminSection(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Cambia de sección desde las pantallas de la consola (por ejemplo, una
/// alerta del resumen abre la moderación filtrada).
class AdminShellScope extends InheritedWidget {
  const AdminShellScope({super.key, required this.select, required super.child});

  final void Function(AdminSection section) select;

  static AdminShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AdminShellScope>();

  @override
  bool updateShouldNotify(AdminShellScope oldWidget) => select != oldWidget.select;
}

/// Consola del administrador con menú lateral. Cada sección conserva su
/// estado; "atrás" vuelve al resumen antes de salir.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  final _scaffold = GlobalKey<ScaffoldState>();
  var _section = AdminSection.summary;

  void _select(AdminSection section) {
    _scaffold.currentState?.closeDrawer();
    if (section != _section) setState(() => _section = section);
  }

  void _openMenu() => _scaffold.currentState?.openDrawer();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _section == AdminSection.summary,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) setState(() => _section = AdminSection.summary);
      },
      child: AdminShellScope(
        select: _select,
        child: NexusMenuScope(
          openMenu: _openMenu,
          child: Scaffold(
            key: _scaffold,
            backgroundColor: NexusColors.bg,
            drawer: _AdminDrawer(selected: _section, onSelect: _select),
            body: LazyIndexedStack(
              index: _section.index,
              children: const [
                AdminDashboardScreen(),
                AdminStoresScreen(),
                AdminModerationScreen(),
                AdminOrdersScreen(),
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

class _AdminDrawer extends ConsumerWidget {
  const _AdminDrawer({required this.selected, required this.onSelect});

  final AdminSection selected;
  final ValueChanged<AdminSection> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Lo que espera al administrador, junto a su sección.
    final badges = ref.watch(
      adminDashboardProvider.select(
        (dashboard) => (
          review: dashboard.value?.reviewOffers ?? 0,
          orders: (dashboard.value?.ordersIncident ?? 0) + (dashboard.value?.ordersStale ?? 0),
          stores: dashboard.value?.providersIn('pending') ?? 0,
        ),
      ),
    );
    int badgeFor(AdminSection section) => switch (section) {
      AdminSection.moderation => badges.review,
      AdminSection.orders => badges.orders,
      AdminSection.stores => badges.stores,
      _ => 0,
    };

    return Drawer(
      backgroundColor: NexusColors.bgAlt,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CONSOLA DE NEXUS',
                    style: TextStyle(fontSize: 10, letterSpacing: 0.8, color: NexusColors.textDim),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Administración',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: NexusColors.text),
                  ),
                ],
              ),
            ),
            const Divider(color: NexusColors.border, height: 1),
            const SizedBox(height: 8),
            for (final section in AdminSection.values)
              ListTile(
                leading: Icon(section.icon, color: section == selected ? NexusColors.cyan : NexusColors.textDim),
                title: Text(
                  section.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: section == selected ? FontWeight.bold : FontWeight.normal,
                    color: section == selected ? NexusColors.cyan : NexusColors.text,
                  ),
                ),
                trailing: badgeFor(section) > 0
                    ? Badge(label: Text('${badgeFor(section)}'), backgroundColor: NexusColors.pink)
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
