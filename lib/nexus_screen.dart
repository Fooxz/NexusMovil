// lib/main.dart
//
// NEXUS — Tienda de Tecnología
// Réplica estática de la pantalla mostrada en la captura.
// Sin lógica de negocio: solo la interfaz visual, tal como se ve.
//
// Cómo usarlo:
// 1. flutter create nexus_app
// 2. Reemplaza el contenido de lib/main.dart por este archivo.
// 3. flutter run

import 'package:flutter/material.dart';

void main() => runApp(const NexusApp());

class NexusApp extends StatelessWidget {
  const NexusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NEXUS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: NexusColors.bg,
        fontFamily: 'Segoe UI',
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: NexusColors.cyan,
          surface: NexusColors.bg,
        ),
      ),
      home: const NexusHomeScreen(),
    );
  }
}

/// Paleta de colores usada en toda la pantalla.
class NexusColors {
  static const bg = Color(0xFF0B0D10);
  static const bgAlt = Color(0xFF12151A);
  static const card = Color(0xFF161A20);
  static const border = Color(0xFF232830);
  static const cyan = Color(0xFF3EE6E0);
  static const text = Color(0xFFF2F4F6);
  static const textDim = Color(0xFF9AA4AE);
  static const textFaint = Color(0xFF5C6570);
}

class NexusHomeScreen extends StatelessWidget {
  const NexusHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NexusColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              _AppBar(),
              _Hero(),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 16),
                    _ProductStrip(),
                    SizedBox(height: 22),
                    _SectionTitle('EXPLORAR CATEGORÍAS'),
                    SizedBox(height: 12),
                    _CategoryGrid(),
                    SizedBox(height: 24),
                    _SectionTitle('TENDENCIAS DEL MOMENTO'),
                    SizedBox(height: 12),
                    _TrendingRow(),
                    SizedBox(height: 24),
                    _FeatureGrid(),
                    SizedBox(height: 26),
                  ],
                ),
              ),
              _Footer(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const _NexusBottomNav(),
    );
  }
}

// ---------------------------------------------------------------------------
// App bar
// ---------------------------------------------------------------------------

class _AppBar extends StatelessWidget {
  const _AppBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          Text(
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
              Icon(
                Icons.shopping_cart_outlined,
                size: 20,
                color: NexusColors.text,
              ),
              SizedBox(width: 16),
              Icon(Icons.menu, size: 20, color: NexusColors.text),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: NexusColors.cyan.withValues(alpha: 0.12),
              border: Border.all(
                color: NexusColors.cyan.withValues(alpha: 0.5),
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'NEXUS TECH STORE',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: NexusColors.cyan,
              ),
            ),
          ),
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
              style: TextStyle(
                fontSize: 11.5,
                height: 1.5,
                color: NexusColors.textDim,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton(
                onPressed: () {},
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
                onPressed: () {},
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
      children: const [
        Expanded(
          child: _ProductCard(
            icon: Icons.memory,
            iconColor: Color(0xFFFF6B5C),
            thumbGradient: [
              Color(0xFF1A1A1A),
              Color(0xFF3A1010),
              Color(0xFF8A1C1C),
            ],
            name: 'RTX 5080',
            price: '\$1,199.99',
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _ProductCard(
            icon: Icons.dns_outlined,
            iconColor: NexusColors.cyan,
            thumbGradient: [
              Color(0xFF0D0D0D),
              Color(0xFF101820),
              Color(0xFF173A33),
            ],
            name: 'CORE 64G',
            price: '\$249.99',
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _ProductCard(
            icon: Icons.flight,
            iconColor: NexusColors.text,
            thumbGradient: [Color(0xFF0F1113), Color(0xFF1C2226)],
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
    required this.thumbGradient,
    required this.name,
    required this.price,
  });

  final IconData icon;
  final Color iconColor;
  final List<Color> thumbGradient;
  final String name;
  final String price;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: NexusColors.card,
        border: Border.all(color: NexusColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: thumbGradient,
              ),
            ),
            child: Icon(
              icon,
              size: 30,
              color: iconColor.withValues(alpha: 0.9),
            ),
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
    );
  }
}

// ---------------------------------------------------------------------------
// Section title with rule lines
// ---------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: NexusColors.border, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              letterSpacing: 1.5,
              fontWeight: FontWeight.bold,
              color: NexusColors.textDim,
            ),
          ),
        ),
        const Expanded(child: Divider(color: NexusColors.border, height: 1)),
      ],
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
    // 3 columnas: (ancho total - 2 gaps de 8) / 3
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: (constraints.maxWidth - 16) / 3,
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
      children: const [
        Expanded(
          child: _TrendCard(
            icon: Icons.smartphone,
            gradient: RadialGradient(
              colors: [Color(0xFF2A2F36), Color(0xFF0C0E11)],
            ),
            name: 'SAMSUNG S24\nULTRA',
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _TrendCard(
            icon: Icons.tablet_mac,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF12181C), Color(0xFF0A3F45), Color(0xFF1FB3AE)],
            ),
            name: 'IPAD PRO',
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _TrendCard(
            icon: Icons.desktop_windows_outlined,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A0E2E), Color(0xFF0E2140), Color(0xFF0A3B52)],
            ),
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
    required this.gradient,
    required this.name,
  });

  final IconData icon;
  final Gradient gradient;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: NexusColors.card,
        border: Border.all(color: NexusColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 70,
            alignment: Alignment.center,
            decoration: BoxDecoration(gradient: gradient),
            child: Icon(
              icon,
              size: 26,
              color: const Color(0xFFEAFFFE).withValues(alpha: 0.85),
            ),
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
      children: const [
        Expanded(
          child: _FeatureCard(
            gradientColors: [Color(0xFF123A3C), Color(0xFF0A1416)],
            title: 'PC BUILDER',
            subtitle: 'CREA TU SETUP\nPERFECTO',
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _FeatureCard(
            gradientColors: [Color(0xFF1A2F4A), Color(0xFF0A1416)],
            title: 'COMPARADOR DE\nPRODUCTOS',
            subtitle: 'ENCUENTRA ENTRE TUS\nFAVORITOS',
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
  });

  final List<Color> gradientColors;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            '© 2024 NEXUS. ALL RIGHTS RESERVED.',
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

// ---------------------------------------------------------------------------
// Bottom navigation
// ---------------------------------------------------------------------------

class _NexusBottomNav extends StatelessWidget {
  const _NexusBottomNav();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: NexusColors.bgAlt,
        border: Border(top: BorderSide(color: NexusColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: BottomNavigationBar(
          currentIndex: 0,
          onTap: (_) {},
          type: BottomNavigationBarType.fixed,
          backgroundColor: NexusColors.bgAlt,
          selectedItemColor: NexusColors.cyan,
          unselectedItemColor: NexusColors.textFaint,
          selectedFontSize: 8,
          unselectedFontSize: 8,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined, size: 18),
              activeIcon: Icon(Icons.home, size: 18),
              label: 'INICIO',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_outlined, size: 18),
              label: 'CATÁLOGO',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.dvr_outlined, size: 18),
              label: 'PC BUILDER',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined, size: 18),
              label: 'COMPARADOR',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline, size: 18),
              label: 'PERFIL',
            ),
          ],
        ),
      ),
    );
  }
}
