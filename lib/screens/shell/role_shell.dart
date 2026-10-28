import 'package:flutter/material.dart';

import '../../features/account/presentation/staff_account_screen.dart';
import '../../features/admin/presentation/admin_stores_screen.dart';
import '../../features/catalog/presentation/catalog_screen.dart';
import '../../features/provider_portal/presentation/my_offers_screen.dart';
import '../../theme/nexus_theme.dart';
import '../../widgets/lazy_indexed_stack.dart';

class RoleTab {
  const RoleTab({required this.label, required this.icon, required this.screen});

  final String label;
  final IconData icon;
  final Widget screen;
}

/// Navegación de las cuentas de tienda: sus publicaciones, el catálogo (para
/// ver la competencia; sin carrito) y la cuenta.
class ProviderShell extends StatelessWidget {
  const ProviderShell({super.key});

  @override
  Widget build(BuildContext context) => const RoleShell(
    tabs: [
      RoleTab(label: 'PUBLICACIONES', icon: Icons.inventory_2_outlined, screen: MyOffersScreen()),
      RoleTab(label: 'CATÁLOGO', icon: Icons.grid_view_outlined, screen: CatalogScreen()),
      RoleTab(label: 'CUENTA', icon: Icons.person_outline, screen: StaffAccountScreen()),
    ],
  );
}

/// Navegación de los administradores: tiendas, catálogo y cuenta.
class AdminShell extends StatelessWidget {
  const AdminShell({super.key});

  @override
  Widget build(BuildContext context) => const RoleShell(
    tabs: [
      RoleTab(label: 'TIENDAS', icon: Icons.storefront_outlined, screen: AdminStoresScreen()),
      RoleTab(label: 'CATÁLOGO', icon: Icons.grid_view_outlined, screen: CatalogScreen()),
      RoleTab(label: 'CUENTA', icon: Icons.person_outline, screen: StaffAccountScreen()),
    ],
  );
}

/// Pestañas con la barra inferior de NEXUS. Como el shell del cliente, "atrás"
/// vuelve a la primera pestaña antes de salir.
class RoleShell extends StatefulWidget {
  const RoleShell({super.key, required this.tabs});

  final List<RoleTab> tabs;

  @override
  State<RoleShell> createState() => _RoleShellState();
}

class _RoleShellState extends State<RoleShell> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _index != 0) setState(() => _index = 0);
      },
      child: Scaffold(
        body: LazyIndexedStack(
          index: _index,
          children: [for (final tab in widget.tabs) tab.screen],
        ),
        bottomNavigationBar: keyboardOpen
            ? null
            : Container(
                decoration: const BoxDecoration(
                  color: NexusColors.bgAlt,
                  border: Border(top: BorderSide(color: NexusColors.border)),
                ),
                child: SafeArea(
                  top: false,
                  child: BottomNavigationBar(
                    currentIndex: _index,
                    onTap: (index) {
                      if (index != _index) setState(() => _index = index);
                    },
                    type: BottomNavigationBarType.fixed,
                    backgroundColor: NexusColors.bgAlt,
                    selectedItemColor: NexusColors.cyan,
                    unselectedItemColor: NexusColors.textFaint,
                    selectedFontSize: 8,
                    unselectedFontSize: 8,
                    elevation: 0,
                    selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
                    items: [
                      for (final tab in widget.tabs)
                        BottomNavigationBarItem(
                          icon: Icon(tab.icon, size: 18),
                          label: tab.label,
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
