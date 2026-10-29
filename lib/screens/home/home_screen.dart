// lib/screens/home/home_screen.dart
//
// Pantalla de inicio del cliente: dirección de entrega, búsqueda, el
// asistente, las categorías, las ofertas reales del catálogo, el PC Builder
// y las tiendas. Cada elemento navega a su pantalla.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/account/account_providers.dart';
import '../../features/auth/auth_providers.dart';
import '../../features/catalog/catalog_providers.dart';
import '../../features/catalog/domain/product.dart';
import '../../features/catalog/presentation/catalog_offer_card.dart';
import '../../features/catalog/presentation/product_visuals.dart';
import '../../features/catalog/presentation/store_catalog_screen.dart';
import '../../features/profile/profile_providers.dart';
import '../../routes.dart';
import '../../theme/nexus_theme.dart';
import '../../widgets/nexus_cart_badge.dart';
import '../../widgets/nexus_menu_scope.dart';
import '../../widgets/nexus_widgets.dart';
import '../shell/main_shell.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NexusColors.bg,
      body: SafeArea(
        // Deslizar hacia abajo vuelve a pedir las ofertas y las tiendas: la
        // pestaña queda viva y sin esto conservaría lo que cargó al abrir.
        child: RefreshIndicator(
          color: NexusColors.cyan,
          onRefresh: () async {
            final container = ProviderScope.containerOf(context);
            container
              ..invalidate(homeDealsProvider)
              ..invalidate(homeStoresProvider);
            await container.read(homeDealsProvider.future);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cabecera clara sobre la tarjeta: dirección, búsqueda y banner.
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  decoration: const BoxDecoration(
                    color: NexusColors.bgAlt,
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HomeHeader(),
                      SizedBox(height: 14),
                      _SearchBar(),
                      SizedBox(height: 14),
                      _AssistantBanner(),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: 22),
                      _Categories(),
                      SizedBox(height: 24),
                      _Deals(),
                      SizedBox(height: 24),
                      _BuildTools(),
                      SizedBox(height: 24),
                      _Stores(),
                      SizedBox(height: 26),
                    ],
                  ),
                ),
                const _Footer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// El shell del cliente; fuera de él (pruebas), el inicio no navega entre
/// pestañas.
void _selectTab(BuildContext context, NexusTab tab) => MainShellScope.maybeOf(context)?.selectTab(tab);

// ---------------------------------------------------------------------------
// Cabecera: menú, dirección de entrega y carrito
// ---------------------------------------------------------------------------

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    final menu = NexusMenuScope.maybeOf(context);
    final cartEnabled = NexusCartBadge.enabledOf(context);
    final cartCount = NexusCartBadge.countOf(context);

    return Row(
      children: [
        _CircleButton(tooltip: 'Abrir menú', icon: Icons.menu, filled: true, onTap: menu?.openMenu),
        const SizedBox(width: 10),
        const Expanded(child: _DeliveryAddress()),
        const SizedBox(width: 10),
        if (cartEnabled)
          _CircleButton(
            tooltip: 'Carrito',
            icon: Icons.shopping_cart_outlined,
            badge: cartCount,
            onTap: () => Navigator.of(context).pushNamed(NexusRoutes.cart),
          )
        else
          const SizedBox(width: 42),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.filled = false,
    this.badge = 0,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: filled ? NexusColors.cyan : NexusColors.card,
      shape: CircleBorder(side: filled ? BorderSide.none : const BorderSide(color: NexusColors.border)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, size: 20, color: filled ? NexusColors.onCyan : NexusColors.text),
        ),
      ),
    );
    return Tooltip(
      message: tooltip,
      child: badge > 0
          ? Badge(label: Text('$badge'), backgroundColor: NexusColors.pink, textColor: Colors.white, child: button)
          : button,
    );
  }
}

/// "Entregar en": la dirección principal del cliente. Sin sesión invita a
/// entrar; sin direcciones, a agregar una en el perfil.
class _DeliveryAddress extends ConsumerWidget {
  const _DeliveryAddress();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(currentUserProvider) != null;
    final canBuy = ref.watch(canBuyProvider);
    final addresses = signedIn && canBuy ? ref.watch(addressesProvider).value : null;
    final address = addresses == null || addresses.isEmpty
        ? null
        : addresses.firstWhere((a) => a.isDefault, orElse: () => addresses.first);

    final (label, onTap) = switch ((signedIn, address)) {
      (false, _) => ('Inicia sesión para comprar', () => Navigator.of(context).pushNamed(NexusRoutes.login)),
      (true, null) => ('Agrega tu dirección', () => _selectTab(context, NexusTab.profile)),
      (true, final address?) => (
        '${address.addressLine}, ${address.city}',
        () => _selectTab(context, NexusTab.profile),
      ),
    };

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: canBuy || !signedIn ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Text(
              signedIn && !canBuy ? 'NEXUS' : 'Entregar en',
              style: const TextStyle(fontSize: 10.5, color: NexusColors.textDim),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    signedIn && !canBuy ? 'Catálogo de piezas' : label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: NexusColors.text),
                  ),
                ),
                if (canBuy || !signedIn) const Icon(Icons.keyboard_arrow_down, size: 18, color: NexusColors.cyan),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Búsqueda y banner del asistente
// ---------------------------------------------------------------------------

/// Abre el catálogo, donde está el buscador con sus filtros.
class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Buscar en el catálogo',
      child: Material(
        color: NexusColors.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _selectTab(context, NexusTab.catalog),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              border: Border.all(color: NexusColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.search, size: 20, color: NexusColors.textDim),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Buscar procesadores, gráficas, memorias…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: NexusColors.textFaint),
                  ),
                ),
                Icon(Icons.tune, size: 18, color: NexusColors.cyan),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AssistantBanner extends StatelessWidget {
  const _AssistantBanner();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _selectTab(context, NexusTab.assistant),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFF0D1418), Color(0xFF123A3C), Color(0xFF1C3A40)],
            ),
            border: Border.all(color: NexusColors.cyan.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const NexusTag('ASISTENTE IA'),
                    const SizedBox(height: 8),
                    const Text(
                      'ARMA TU PC\nCON IA',
                      style: TextStyle(
                        fontSize: 20,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Dile qué necesitas y te armamos un PC compatible con piezas en stock.',
                      style: NexusText.body,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(color: NexusColors.cyan, borderRadius: BorderRadius.circular(8)),
                      child: const Text(
                        'PREGUNTAR AL ASISTENTE',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                          color: NexusColors.onCyan,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: NexusColors.cyan.withValues(alpha: 0.1),
                  boxShadow: [BoxShadow(color: NexusColors.cyan.withValues(alpha: 0.25), blurRadius: 24)],
                ),
                child: const Icon(Icons.auto_awesome, size: 34, color: NexusColors.cyan),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Secciones
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.badge, this.onSeeAll});

  final String title;
  final Widget? badge;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: Colors.white),
          ),
        ),
        if (badge != null) ...[const SizedBox(width: 10), badge!],
        const Spacer(),
        if (onSeeAll != null)
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onSeeAll,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Ver todo', style: TextStyle(fontSize: 12, color: NexusColors.textDim)),
                  const SizedBox(width: 6),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(color: NexusColors.card, shape: BoxShape.circle),
                    child: const Icon(Icons.chevron_right, size: 16, color: NexusColors.text),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Categories extends ConsumerWidget {
  const _Categories();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void open(ProductCategory? category) {
      ref.read(catalogControllerProvider.notifier).setCategory(category);
      _selectTab(context, NexusTab.catalog);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(title: 'CATEGORÍAS', onSeeAll: () => open(null)),
        const SizedBox(height: 14),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: ProductCategory.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final category = ProductCategory.values[index];
              final visuals = ProductVisuals.forCategory(category);
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => open(category),
                child: SizedBox(
                  width: 66,
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: NexusColors.card,
                          shape: BoxShape.circle,
                          border: Border.all(color: NexusColors.border),
                        ),
                        child: Icon(visuals.icon, size: 26, color: NexusColors.cyan),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ProductVisuals.chipLabel(category),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11, color: NexusColors.text),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Ofertas reales: las piezas con mayor descuento y stock.
class _Deals extends ConsumerWidget {
  const _Deals();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deals = ref.watch(homeDealsProvider);
    final data = deals.value;
    final best = data == null || !data.discounted || data.items.isEmpty ? null : data.items.first.discountPercent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          title: data?.discounted == false ? 'DESTACADOS' : 'OFERTAS',
          badge: best == null
              ? null
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: NexusColors.pink, borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    'HASTA -$best%',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
          onSeeAll: () {
            ref.read(catalogControllerProvider.notifier).setCategory(null);
            _selectTab(context, NexusTab.catalog);
          },
        ),
        const SizedBox(height: 14),
        switch (deals) {
          AsyncValue(value: final data?) when data.items.isEmpty => const Text(
            'Pronto tendremos piezas en oferta.',
            style: TextStyle(fontSize: 12, color: NexusColors.textDim),
          ),
          AsyncValue(value: final data?) => GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: data.items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.64,
            ),
            itemBuilder: (context, index) => CatalogOfferCard(offer: data.items[index]),
          ),
          AsyncValue(error: _?) => Row(
            children: [
              const Expanded(
                child: Text(
                  'No se pudieron cargar las ofertas.',
                  style: TextStyle(fontSize: 12, color: NexusColors.textDim),
                ),
              ),
              TextButton(onPressed: () => ref.invalidate(homeDealsProvider), child: const Text('Reintentar')),
            ],
          ),
          _ => const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator(color: NexusColors.cyan, strokeWidth: 2)),
          ),
        },
      ],
    );
  }
}

/// Las dos formas de armar un equipo: el PC Builder y el asistente.
class _BuildTools extends StatelessWidget {
  const _BuildTools();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(title: 'ARMA TU EQUIPO'),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _ToolCard(
                icon: Icons.build_circle_outlined,
                title: 'PC BUILDER',
                subtitle: 'Elige pieza por pieza con compatibilidad garantizada y vista 3D.',
                gradientColors: const [Color(0xFF123A3C), Color(0xFF0A1416)],
                onTap: () => _selectTab(context, NexusTab.pcBuilder),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ToolCard(
                icon: Icons.auto_awesome_outlined,
                title: 'ASISTENTE IA',
                subtitle: 'Cuéntale al asistente para qué lo quieres y cuánto puedes gastar.',
                gradientColors: const [Color(0xFF1A0E2E), Color(0xFF0E2140)],
                onTap: () => _selectTab(context, NexusTab.assistant),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: NexusColors.border),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradientColors),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 26, color: NexusColors.cyan),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(fontSize: 10.5, height: 1.35, color: NexusColors.textDim)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tiendas que venden en NEXUS; cada una abre su catálogo.
class _Stores extends ConsumerWidget {
  const _Stores();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stores = ref.watch(homeStoresProvider).value;
    if (stores == null || stores.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(title: 'TIENDAS'),
        const SizedBox(height: 14),
        SizedBox(
          height: 64,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: stores.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final store = stores[index];
              return Material(
                color: NexusColors.card,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () =>
                      Navigator.of(context)
                          .pushNamed(NexusRoutes.store, arguments: StoreCatalogArgs(store.id, store.displayName)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: NexusColors.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: NexusColors.cyan.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            store.displayName.isEmpty ? '?' : store.displayName.characters.first.toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w800, color: NexusColors.cyan),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              store.displayName,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: NexusColors.text,
                              ),
                            ),
                            Text(
                              store.offerCount == 1 ? '1 pieza' : '${store.offerCount} piezas',
                              style: const TextStyle(fontSize: 10.5, color: NexusColors.textDim),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Pie
// ---------------------------------------------------------------------------

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: NexusColors.border)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'NEXUS',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: NexusColors.text,
                ),
              ),
              SizedBox(width: 8),
              Text('v1.0', style: TextStyle(fontSize: 8, color: NexusColors.textFaint)),
            ],
          ),
          SizedBox(height: 4),
          Text(
            '// La tech que quieres, al siguiente nivel.',
            style: TextStyle(fontSize: 9.5, color: NexusColors.textDim),
          ),
          SizedBox(height: 12),
          Text(
            '© 2026 NEXUS. Todos los derechos reservados.',
            style: TextStyle(fontSize: 8, letterSpacing: 0.3, color: NexusColors.textFaint),
          ),
        ],
      ),
    );
  }
}
