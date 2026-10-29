import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_providers.dart';
import '../../features/catalog/catalog_providers.dart';
import '../../features/catalog/domain/product.dart';
import '../../features/catalog/presentation/product_visuals.dart';
import '../../features/profile/profile_providers.dart';
import '../../routes.dart';
import '../../theme/nexus_theme.dart';
import '../../widgets/nexus_cart_badge.dart';
import 'main_shell.dart';

/// Menú lateral del cliente: su cuenta, las secciones de la app, el carrito y
/// las categorías del catálogo. Sin sesión ofrece entrar o crear la cuenta.
class CustomerDrawer extends ConsumerWidget {
  const CustomerDrawer({super.key, required this.current, required this.onSelectTab});

  final NexusTab current;
  final ValueChanged<NexusTab> onSelectTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final cartCount = NexusCartBadge.countOf(context);

    void go(NexusTab tab) {
      Navigator.of(context).pop();
      onSelectTab(tab);
    }

    void push(String route) {
      final navigator = Navigator.of(context)..pop();
      navigator.pushNamed(route);
    }

    void openCategory(ProductCategory category) {
      ref.read(catalogControllerProvider.notifier).setCategory(category);
      go(NexusTab.catalog);
    }

    return Drawer(
      backgroundColor: NexusColors.bgAlt,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _AccountHeader(signedIn: user != null, onSignIn: () => push(NexusRoutes.login), onSignUp: () => push(NexusRoutes.signup)),
            const Divider(color: NexusColors.border, height: 1),
            const SizedBox(height: 6),
            _Item(icon: Icons.home_outlined, label: 'Inicio', selected: current == NexusTab.home, onTap: () => go(NexusTab.home)),
            _Item(icon: Icons.grid_view_outlined, label: 'Catálogo', selected: current == NexusTab.catalog, onTap: () => go(NexusTab.catalog)),
            _Item(
              icon: Icons.auto_awesome_outlined,
              label: 'Asistente de compra',
              selected: current == NexusTab.assistant,
              onTap: () => go(NexusTab.assistant),
            ),
            _Item(
              icon: Icons.build_circle_outlined,
              label: 'PC Builder',
              selected: current == NexusTab.pcBuilder,
              onTap: () => go(NexusTab.pcBuilder),
            ),
            _Item(
              icon: Icons.shopping_cart_outlined,
              label: 'Carrito',
              onTap: () => push(NexusRoutes.cart),
              trailing: cartCount > 0 ? Badge(label: Text('$cartCount'), backgroundColor: NexusColors.cyan, textColor: NexusColors.onCyan) : null,
            ),
            _Item(
              icon: Icons.person_outline,
              label: user == null ? 'Perfil' : 'Mi perfil y direcciones',
              selected: current == NexusTab.profile,
              onTap: () => go(NexusTab.profile),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text('CATEGORÍAS', style: NexusText.sectionLabel),
            ),
            for (final category in ProductCategory.values)
              _Item(
                icon: ProductVisuals.forCategory(category).icon,
                label: ProductVisuals.forCategory(category).categoryLabel,
                dense: true,
                onTap: () => openCategory(category),
              ),
            if (user != null) ...[
              const SizedBox(height: 8),
              const Divider(color: NexusColors.border, height: 1),
              _Item(
                icon: Icons.logout,
                label: 'Cerrar sesión',
                color: NexusColors.pink,
                onTap: () async {
                  Navigator.of(context).pop();
                  await ref.read(authRepositoryProvider).signOut();
                },
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _AccountHeader extends ConsumerWidget {
  const _AccountHeader({required this.signedIn, required this.onSignIn, required this.onSignUp});

  final bool signedIn;
  final VoidCallback onSignIn;
  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = signedIn ? ref.watch(profileProvider).value : null;
    final name = profile?.fullName ?? (signedIn ? 'Mi cuenta' : 'Hola, invitado');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: NexusColors.cyan.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: NexusColors.cyan.withValues(alpha: 0.5)),
                ),
                alignment: Alignment.center,
                child: signedIn
                    ? Text(
                        name.characters.first.toUpperCase(),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: NexusColors.cyan),
                      )
                    : const Icon(Icons.person_outline, color: NexusColors.cyan),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: NexusColors.text),
                    ),
                    Text(
                      profile?.email ?? 'Inicia sesión para comprar',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: NexusColors.textDim),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!signedIn) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: onSignIn,
                    style: FilledButton.styleFrom(
                      backgroundColor: NexusColors.cyan,
                      foregroundColor: NexusColors.onCyan,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Iniciar sesión', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onSignUp,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: NexusColors.text,
                      side: const BorderSide(color: NexusColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Crear cuenta'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.dense = false,
    this.trailing,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool dense;
  final Widget? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? (selected ? NexusColors.cyan : NexusColors.text);
    return ListTile(
      dense: dense,
      visualDensity: dense ? VisualDensity.compact : null,
      leading: Icon(icon, size: dense ? 19 : 22, color: color ?? (selected ? NexusColors.cyan : NexusColors.textDim)),
      title: Text(
        label,
        style: TextStyle(fontSize: dense ? 13 : 14, fontWeight: selected ? FontWeight.bold : FontWeight.normal, color: tint),
      ),
      trailing: trailing,
      selected: selected,
      onTap: onTap,
    );
  }
}
