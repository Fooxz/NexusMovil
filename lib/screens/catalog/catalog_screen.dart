// lib/screens/catalog/catalog_screen.dart
//
// Catálogo completo: búsqueda, filtros por categoría y grilla de
// productos. Los filtros son visuales (no filtran nada todavía) — eso
// llegará cuando el catálogo esté conectado a los datos reales.

import 'package:flutter/material.dart';

import '../../routes.dart';
import '../../theme/nexus_theme.dart';
import '../../widgets/nexus_bottom_nav.dart';
import '../../widgets/nexus_page.dart';
import '../../widgets/nexus_product_card.dart';
import '../../widgets/nexus_widgets.dart';

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  static const _primaryFilters = [
    'Celular',
    'CPU',
    'GPU',
    'RAM',
    'Motherboard',
  ];
  static const _secondaryFilters = [
    'Almacenamiento',
    'Fuente',
    'Gabinete',
    'Refrigeración',
  ];

  @override
  Widget build(BuildContext context) {
    return NexusPage(
      title: 'CATÁLOGO COMPLETO',
      bottomNavigationBar: const NexusBottomNav(currentIndex: 1),
      children: [
        Padding(
          padding: EdgeInsets.zero,
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
                  for (final f in _primaryFilters)
                    _FilterChip(label: f, active: f == 'Celular'),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: NexusColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Orden: Relevancia',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: NexusColors.textDim,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down,
                          size: 16,
                          color: NexusColors.textDim,
                        ),
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
                children: [
                  NexusProductCard(
                    icon: Icons.videogame_asset,
                    gradientColors: [
                      Color(0xFF1A1A1A),
                      Color(0xFF3A1010),
                      Color(0xFF8A1C1C),
                    ],
                    discountLabel: '-12%',
                    brand: 'NVIDIA / GPU',
                    status: 'ESTABLE',
                    statusColor: NexusColors.cyan,
                    name: 'RTX 5090 FOUNDERS',
                    specs: '24 GB GDDR6X · 2.5K · Ray tracing',
                    oldPriceCents: 229900,
                    priceCents: 199900,
                    onTap: () =>
                        Navigator.of(context)
                            .pushNamed(NexusRoutes.productDetail),
                    actions: _productActions(context),
                  ),
                  NexusProductCard(
                    icon: Icons.memory,
                    gradientColors: [Color(0xFF101010), Color(0xFF1B1B1B)],
                    brand: 'AMD / CPU',
                    status: 'ESTABLE',
                    statusColor: NexusColors.cyan,
                    name: 'RYZEN 9 9950X',
                    specs: '16 núcleos · 5.7 GHz · Zen 5',
                    oldPriceCents: 69900,
                    priceCents: 64900,
                    onTap: () =>
                        Navigator.of(context)
                            .pushNamed(NexusRoutes.productDetail),
                    actions: _productActions(context),
                  ),
                  NexusProductCard(
                    icon: Icons.developer_board,
                    gradientColors: [Color(0xFF14101C), Color(0xFF241735)],
                    discountLabel: '-10%',
                    brand: 'ASUS / MB',
                    status: 'CRÍTICO',
                    statusColor: NexusColors.pink,
                    name: 'ROG MAXIMUS Z790 HERO',
                    specs: 'Z890 · Wi-Fi 7 · 24+2 fases',
                    oldPriceCents: 69999,
                    priceCents: 59999,
                    onTap: () =>
                        Navigator.of(context)
                            .pushNamed(NexusRoutes.productDetail),
                    actions: _productActions(context),
                  ),
                  NexusProductCard(
                    icon: Icons.ac_unit,
                    gradientColors: [Color(0xFF0F1B2E), Color(0xFF14314A)],
                    brand: 'NZXT / LIQUID AIO',
                    status: 'ESTABLE',
                    statusColor: NexusColors.cyan,
                    name: 'KRAKEN ELITE 360',
                    specs: '360 mm · RGB · 2x fans',
                    oldPriceCents: 32999,
                    priceCents: 29999,
                    onTap: () =>
                        Navigator.of(context)
                            .pushNamed(NexusRoutes.productDetail),
                    actions: _productActions(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
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
        border: Border.all(
          color: active ? NexusColors.cyan : NexusColors.border,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: active ? NexusColors.onCyan : NexusColors.text,
        ),
      ),
    );
  }
}

Widget _productActions(BuildContext context) {
  return Row(
    children: [
      Expanded(
        child: NexusOutlineButton(
          label: 'Ver',
          onPressed: () =>
              Navigator.of(context).pushNamed(NexusRoutes.productDetail),
          color: NexusColors.text,
          borderColor: NexusColors.border,
          compact: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          fontSize: 10.5,
          borderRadius: 6,
          bold: false,
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
          child: const Icon(
            Icons.shopping_cart,
            size: 15,
            color: NexusColors.onCyan,
          ),
        ),
      ),
    ],
  );
}
