// lib/screens/home/home_screen.dart
//
// Pantalla de inicio. Es la evolución del primer mockup que armamos:
// ahora cada elemento (productos, categorías, tendencias, tarjetas de
// PC Builder / Comparador, carrito) navega a su pantalla correspondiente.

import 'package:flutter/material.dart';

import '../../routes.dart';
import '../../theme/nexus_theme.dart';
import '../../widgets/nexus_bottom_nav.dart';
import '../../widgets/nexus_widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NexusColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _HomeAppBar(),
              const _Hero(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: const [
                    SizedBox(height: 16),
                    _ProductStrip(),
                    SizedBox(height: 22),
                    NexusBracketTitle('EXPLORAR CATEGORÍAS'),
                    SizedBox(height: 12),
                    _CategoryGrid(),
                    SizedBox(height: 24),
                    NexusBracketTitle('TENDENCIAS DEL MOMENTO'),
                    SizedBox(height: 12),
                    _TrendingRow(),
                    SizedBox(height: 24),
                    _FeatureGrid(),
                    SizedBox(height: 26),
                  ],
                ),
              ),
              const _Footer(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const NexusBottomNav(currentIndex: 0),
    );
  }
}

// ---------------------------------------------------------------------------
// App bar
// ---------------------------------------------------------------------------

class _HomeAppBar extends StatelessWidget {
  const _HomeAppBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'NEXUS',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              color: NexusColors.text,
            ),
          ),
          Row(
            children: [
              InkWell(
                onTap: () => Navigator.of(context).pushNamed(NexusRoutes.cart),
                child: const Icon(
                  Icons.shopping_cart_outlined,
                  size: 20,
                  color: NexusColors.text,
                ),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.menu, size: 20, color: NexusColors.text),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero
// ---------------------------------------------------------------------------

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      constraints: const BoxConstraints(minHeight: 250),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF1C3A40), Color(0xFF0D1418), Color(0xFF0A0C0F)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const NexusTag('NEXUS TECH STORE'),
          const SizedBox(height: 70),
          const Text(
            'TIENDA DE\nTECNOLOGÍA',
            style: TextStyle(
              fontSize: 26,
              height: 1.05,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'LA TECH QUE QUIERES, AL SIGUIENTE NIVEL',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
              color: NexusColors.cyan,
            ),
          ),
          const SizedBox(height: 8),
          const SizedBox(
            width: 230,
            child: Text(
              'Celulares, laptops, drones, TVs, motos eléctricas y más...',
              style: NexusText.body,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed(NexusRoutes.catalog),
                style: ElevatedButton.styleFrom(
                  backgroundColor: NexusColors.cyan,
                  foregroundColor: const Color(0xFF04211F),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'EXPLORAR CATÁLOGO',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed(NexusRoutes.catalog),
                style: OutlinedButton.styleFrom(
                  foregroundColor: NexusColors.text,
                  side: const BorderSide(color: NexusColors.textFaint),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                child: const Text(
                  'VER CATEGORÍAS',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Product strip
// ---------------------------------------------------------------------------

class _ProductStrip extends StatelessWidget {
  const _ProductStrip();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ProductCard(
            icon: Icons.memory,
            iconColor: const Color(0xFFFF6B5C),
            gradientColors: const [
              Color(0xFF1A1A1A),
              Color(0xFF3A1010),
              Color(0xFF8A1C1C),
            ],
            name: 'RTX 5080',
            price: '\$1,199.99',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ProductCard(
            icon: Icons.dns_outlined,
            iconColor: NexusColors.cyan,
            gradientColors: const [
              Color(0xFF0D0D0D),
              Color(0xFF101820),
              Color(0xFF173A33),
            ],
            name: 'CORE 64G',
            price: '\$249.99',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ProductCard(
            icon: Icons.flight,
            iconColor: NexusColors.text,
            gradientColors: const [Color(0xFF0F1113), Color(0xFF1C2226)],
            name: 'DRONE DJI',
            price: '\$899.99',
          ),
        ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.icon,
    required this.iconColor,
    required this.gradientColors,
    required this.name,
    required this.price,
  });

  final IconData icon;
  final Color iconColor;
  final List<Color> gradientColors;
  final String name;
  final String price;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).pushNamed(NexusRoutes.productDetail),
      child: Container(
        decoration: BoxDecoration(
          color: NexusColors.card,
          border: Border.all(color: NexusColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NexusPlaceholderBox(
              icon: icon,
              iconColor: iconColor,
              gradientColors: gradientColors,
              height: 64,
              borderRadius: 0,
              iconSize: 30,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 7, 8, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                      color: NexusColors.cyan,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    price,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Categories
// ---------------------------------------------------------------------------

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid();

  static const _categories = [
    'CELULARES',
    'LAPTOPS',
    'DRONES',
    'TVS',
    'MOTOS EL.',
    'AUDIO',
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _categories.map((c) => _CategoryChip(label: c)).toList(),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: (constraints.maxWidth - 16) / 3,
          child: InkWell(
            onTap: () => Navigator.of(context).pushNamed(NexusRoutes.catalog),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: BoxDecoration(
                color: NexusColors.card,
                border: Border.all(color: NexusColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                  color: NexusColors.text,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Trending row
// ---------------------------------------------------------------------------

class _TrendingRow extends StatelessWidget {
  const _TrendingRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TrendCard(
            icon: Icons.smartphone,
            gradientColors: const [Color(0xFF2A2F36), Color(0xFF0C0E11)],
            name: 'SAMSUNG S24\nULTRA',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _TrendCard(
            icon: Icons.tablet_mac,
            gradientColors: const [
              Color(0xFF12181C),
              Color(0xFF0A3F45),
              Color(0xFF1FB3AE),
            ],
            name: 'IPAD PRO',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _TrendCard(
            icon: Icons.desktop_windows_outlined,
            gradientColors: const [
              Color(0xFF1A0E2E),
              Color(0xFF0E2140),
              Color(0xFF0A3B52),
            ],
            name: '4K MONITOR',
          ),
        ),
      ],
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.icon,
    required this.gradientColors,
    required this.name,
  });

  final IconData icon;
  final List<Color> gradientColors;
  final String name;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).pushNamed(NexusRoutes.productDetail),
      child: Container(
        decoration: BoxDecoration(
          color: NexusColors.card,
          border: Border.all(color: NexusColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NexusPlaceholderBox(
              icon: icon,
              iconColor: const Color(0xFFEAFFFE),
              gradientColors: gradientColors,
              height: 70,
              borderRadius: 0,
              iconSize: 26,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 7, 6, 9),
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  color: NexusColors.textDim,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Feature grid (PC Builder / Comparador)
// ---------------------------------------------------------------------------

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _FeatureCard(
            gradientColors: const [Color(0xFF123A3C), Color(0xFF0A1416)],
            title: 'PC BUILDER',
            subtitle: 'CREA TU SETUP\nPERFECTO',
            onTap: () => Navigator.of(context).pushNamed(NexusRoutes.pcBuilder),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _FeatureCard(
            gradientColors: const [Color(0xFF1A2F4A), Color(0xFF0A1416)],
            title: 'COMPARADOR DE\nPRODUCTOS',
            subtitle: 'ENCUENTRA ENTRE TUS\nFAVORITOS',
            onTap: () =>
                Navigator.of(context).pushNamed(NexusRoutes.comparator),
          ),
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.gradientColors,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final List<Color> gradientColors;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 110),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
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
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
                height: 1.4,
                color: NexusColors.cyan,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Footer
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: const [
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
              Text(
                'v1.0',
                style: TextStyle(fontSize: 8, color: NexusColors.textFaint),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '// La tech que quieres, al siguiente nivel.',
            style: TextStyle(fontSize: 9.5, color: NexusColors.textDim),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: const [
              Text(
                'NOSOTROS',
                style: TextStyle(fontSize: 9, color: NexusColors.textDim),
              ),
              Text(
                'PRIVACIDAD',
                style: TextStyle(fontSize: 9, color: NexusColors.textDim),
              ),
              Text(
                'TÉRMINOS',
                style: TextStyle(fontSize: 9, color: NexusColors.textDim),
              ),
              Text(
                'CONTACTO',
                style: TextStyle(fontSize: 9, color: NexusColors.textDim),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            '© 2026 NEXUS. ALL RIGHTS RESERVED.',
            style: TextStyle(
              fontSize: 8,
              letterSpacing: 0.3,
              color: NexusColors.textFaint,
            ),
          ),
        ],
      ),
    );
  }
}
