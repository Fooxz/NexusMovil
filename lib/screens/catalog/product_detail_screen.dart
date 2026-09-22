// lib/screens/catalog/product_detail_screen.dart
//
// Detalle de producto. Muestra un producto fijo (RTX 5090) a modo de
// mockup: cuando el catálogo esté conectado a datos reales, esta pantalla
// recibirá el producto seleccionado como argumento de la ruta.

import 'package:flutter/material.dart';
import '../../theme/nexus_theme.dart';
import '../../widgets/nexus_bottom_nav.dart';
import '../../widgets/nexus_top_bar.dart';
import '../../widgets/nexus_widgets.dart';

class ProductDetailScreen extends StatelessWidget {
  const ProductDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NexusColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const NexusTopBar(title: 'DETALLES DEL PRODUCTO', showBack: true),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Breadcrumb(),
                    const SizedBox(height: 14),
                    Container(
                      height: 230,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: NexusColors.cyan.withValues(alpha: 0.5)),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF0E1B1E), Color(0xFF0A1214)],
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.videogame_asset, size: 64, color: NexusColors.cyan),
                    ),
                    const SizedBox(height: 14),
                    const Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        NexusTag('NVIDIA'),
                        NexusTag('TARJETAS GRÁFICAS'),
                        NexusTag('EN STOCK', color: NexusColors.green),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'NVIDIA GEFORCE RTX 5090',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          '\$1,999.00',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: NexusColors.cyan,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '\$2,299.00',
                          style: TextStyle(
                            fontSize: 13,
                            color: NexusColors.textFaint,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: NexusColors.pink,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '-13%',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const NexusUnderlineTitle('SPECS RÁPIDAS'),
                    const SizedBox(height: 10),
                    const Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        NexusTag('ADALACE'),
                        NexusTag('16384 CORES'),
                        NexusTag('24GB GDDR6X'),
                        NexusTag('450W'),
                        NexusTag('PCI-E 5.0'),
                        NexusTag('ATX'),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: NexusColors.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: () {},
                                icon: const Icon(Icons.remove, size: 16, color: NexusColors.textDim),
                              ),
                              const Text(
                                '01',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: NexusColors.text),
                              ),
                              IconButton(
                                onPressed: () {},
                                icon: const Icon(Icons.add, size: 16, color: NexusColors.textDim),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: NexusColors.pink,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                            child: const Text(
                              'COMPRAR AHORA',
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.shopping_cart, size: 15),
                            label: const Text(
                              'AGREGAR AL CARRITO',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: NexusColors.cyan,
                              foregroundColor: const Color(0xFF04211F),
                              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const NexusUnderlineTitle('ESPECIFICACIONES COMPLETAS'),
                    const SizedBox(height: 4),
                    NexusCard(
                      child: Column(
                        children: const [
                          NexusSpecRow('MARCA', 'NVIDIA'),
                          Divider(color: NexusColors.border, height: 1),
                          NexusSpecRow('CATEGORÍA', 'TARJETAS GRÁFICAS'),
                          Divider(color: NexusColors.border, height: 1),
                          NexusSpecRow('ESTADO', 'EN STOCK', valueColor: NexusColors.green),
                          Divider(color: NexusColors.border, height: 1),
                          NexusSpecRow('ARQUITECTURA', 'ADALACE'),
                          Divider(color: NexusColors.border, height: 1),
                          NexusSpecRow('CORES', '16384'),
                          Divider(color: NexusColors.border, height: 1),
                          NexusSpecRow('VRAM', '24GB GDDR6X'),
                          Divider(color: NexusColors.border, height: 1),
                          NexusSpecRow('TDP', '450W'),
                          Divider(color: NexusColors.border, height: 1),
                          NexusSpecRow('INTERFAZ', 'PCI-E 5.0 x16'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    const NexusUnderlineTitle('TAMBIÉN TE PUEDE INTERESAR'),
                    const SizedBox(height: 10),
                    Row(
                      children: const [
                        Expanded(
                          child: _RelatedCard(
                            icon: Icons.videogame_asset_outlined,
                            gradientColors: [Color(0xFF141414), Color(0xFF23364A)],
                            tags: ['RTX 5080', '16GB'],
                            name: 'NVIDIA RTX 5080',
                            price: '\$1,699.00',
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: _RelatedCard(
                            icon: Icons.ac_unit,
                            gradientColors: [Color(0xFF141414), Color(0xFF3A1030)],
                            tags: ['LIQUID', '360MM'],
                            name: 'Cooler Master Elite Liquid 360',
                            price: '\$249.00',
                          ),
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

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb();

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: const TextSpan(
        style: TextStyle(fontSize: 9.5, color: NexusColors.textFaint, letterSpacing: 0.3),
        children: [
          TextSpan(text: 'INICIO > PRODUCTOS > TARJETAS GRÁFICAS > '),
          TextSpan(
            text: 'RTX 5090',
            style: TextStyle(color: NexusColors.cyan, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _RelatedCard extends StatelessWidget {
  const _RelatedCard({
    required this.icon,
    required this.gradientColors,
    required this.tags,
    required this.name,
    required this.price,
  });

  final IconData icon;
  final List<Color> gradientColors;
  final List<String> tags;
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
          NexusPlaceholderBox(icon: icon, gradientColors: gradientColors, height: 74, borderRadius: 0),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 7, 8, 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [for (final t in tags) NexusTag(t)],
                ),
                const SizedBox(height: 6),
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  price,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: NexusColors.cyan),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
