// lib/screens/catalog/catalog_screen.dart
//
// Catálogo completo: búsqueda, filtros por categoría y grilla de
// productos. Los filtros son visuales (no filtran nada todavía) — eso
// llegará cuando el catálogo esté conectado a los datos reales.

import 'package:flutter/material.dart';
import '../../routes.dart';
import '../../theme/nexus_theme.dart';
import '../../widgets/nexus_bottom_nav.dart';
import '../../widgets/nexus_top_bar.dart';
import '../../widgets/nexus_widgets.dart';

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  static const _primaryFilters = ['Celular', 'CPU', 'GPU', 'RAM', 'Motherboard'];
  static const _secondaryFilters = ['Almacenamiento', 'Fuente', 'Gabinete', 'Refrigeración'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NexusColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const NexusTopBar(title: 'CATÁLOGO COMPLETO'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const NexusTextField(
                      hint: 'Buscar producto, marca o categoría',
                      prefixIcon: Icons.search,
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final f in _primaryFilters) _FilterChip(label: f, active: f == 'Celular'),
                        for (final f in _secondaryFilters) _FilterChip(label: f),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '128 productos',
                          style: TextStyle(fontSize: 12, color: NexusColors.textDim),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: NexusColors.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Orden: Relevancia',
                                style: TextStyle(fontSize: 10.5, color: NexusColors.textDim),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.keyboard_arrow_down, size: 16, color: NexusColors.textDim),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.72,
                      children: const [
                        _ProductGridCard(
                          icon: Icons.videogame_asset,
                          gradientColors: [Color(0xFF1A1A1A), Color(0xFF3A1010), Color(0xFF8A1C1C)],
                          discount: '-12%',
                          brand: 'NVIDIA / GPU',
                          status: 'ESTABLE',
                          statusColor: NexusColors.cyan,
                          name: 'RTX 5090 FOUNDERS',
                          specs: '24 GB GDDR6X · 2.5K · Ray tracing',
                          oldPrice: '\$2,299.00',
                          price: '\$1,999.00',
                        ),
                        _ProductGridCard(
                          icon: Icons.memory,
                          gradientColors: [Color(0xFF101010), Color(0xFF1B1B1B)],
                          brand: 'AMD / CPU',
                          status: 'ESTABLE',
                          statusColor: NexusColors.cyan,
                          name: 'RYZEN 9 9950X',
                          specs: '16 núcleos · 5.7 GHz · Zen 5',
                          oldPrice: '\$699.00',
                          price: '\$649.00',
                        ),
                        _ProductGridCard(
                          icon: Icons.developer_board,
                          gradientColors: [Color(0xFF14101C), Color(0xFF241735)],
                          discount: '-10%',
                          brand: 'ASUS / MB',
                          status: 'CRÍTICO',
                          statusColor: NexusColors.pink,
                          name: 'ROG MAXIMUS Z790 HERO',
                          specs: 'Z890 · Wi-Fi 7 · 24+2 fases',
                          oldPrice: '\$699.99',
                          price: '\$599.99',
                        ),
                        _ProductGridCard(
                          icon: Icons.ac_unit,
                          gradientColors: [Color(0xFF0F1B2E), Color(0xFF14314A)],
                          brand: 'NZXT / LIQUID AIO',
                          status: 'ESTABLE',
                          statusColor: NexusColors.cyan,
                          name: 'KRAKEN ELITE 360',
                          specs: '360 mm · RGB · 2x fans',
                          oldPrice: '\$329.99',
                          price: '\$299.99',
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const NexusBottomNav(currentIndex: 1),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, this.active = false});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: active ? NexusColors.cyan : NexusColors.card,
        border: Border.all(color: active ? NexusColors.cyan : NexusColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: active ? const Color(0xFF04211F) : NexusColors.text,
        ),
      ),
    );
  }
}

class _ProductGridCard extends StatelessWidget {
  const _ProductGridCard({
    required this.icon,
    required this.gradientColors,
    required this.brand,
    required this.status,
    required this.statusColor,
    required this.name,
    required this.specs,
    required this.oldPrice,
    required this.price,
    this.discount,
  });

  final IconData icon;
  final List<Color> gradientColors;
  final String? discount;
  final String brand;
  final String status;
  final Color statusColor;
  final String name;
  final String specs;
  final String oldPrice;
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
            Stack(
              children: [
                NexusPlaceholderBox(
                  icon: icon,
                  gradientColors: gradientColors,
                  height: 84,
                  borderRadius: 0,
                ),
                if (discount != null)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: NexusColors.pink,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        discount!,
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 7, 8, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          brand,
                          style: const TextStyle(fontSize: 8, color: NexusColors.textFaint),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      NexusStatusDot(status, color: statusColor),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    specs,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 8, color: NexusColors.textDim),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        oldPrice,
                        style: const TextStyle(
                          fontSize: 9,
                          color: NexusColors.textFaint,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          price,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: NexusColors.cyan,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pushNamed(NexusRoutes.productDetail),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: NexusColors.text,
                            side: const BorderSide(color: NexusColors.border),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          child: const Text('Ver', style: TextStyle(fontSize: 10.5)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () {},
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: NexusColors.cyan,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.shopping_cart, size: 15, color: Color(0xFF04211F)),
                        ),
                      ),
                    ],
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
