// lib/screens/cart/cart_screen.dart
//
// Carrito de compra. Los artículos y totales están fijos (mockup) — el
// cálculo real vendrá cuando el carrito se conecte al estado de la app.

import 'package:flutter/material.dart';

import '../../theme/nexus_theme.dart';
import '../../widgets/nexus_bottom_nav.dart';
import '../../widgets/nexus_page.dart';
import '../../widgets/nexus_quantity_stepper.dart';
import '../../widgets/nexus_widgets.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return NexusPage(
      title: 'CARRITO DE COMPRA',
      showBack: true,
      showCart: false,
      bottomNavigationBar: const NexusBottomNav(currentIndex: 1),
      children: [
        const _CartItemCard(
          category: 'GPU',
          icon: Icons.videogame_asset,
          gradientColors: [Color(0xFF16321A), Color(0xFF0D1E10)],
          name: 'RTX 5090 FOUNDERS',
          unitPrice: '\$1,999.00',
          qty: '01',
          subtotal: '\$1,999.00',
        ),
        const SizedBox(height: 12),
        const _CartItemCard(
          category: 'RAM',
          icon: Icons.dns_outlined,
          gradientColors: [Color(0xFF101010), Color(0xFF1C1C1C)],
          name: 'DDR5 VENGEANCE...',
          unitPrice: '\$499.98',
          qty: '02',
          subtotal: '\$999.96',
        ),
        const SizedBox(height: 20),
        NexusCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Resumen del pedido',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 8),
              NexusSpecRow('Artículos', '03'),
              NexusSpecRow('Subtotal', '\$2,998.96'),
              NexusSpecRow('Envío', 'Gratis', valueColor: NexusColors.cyan),
              Divider(color: NexusColors.border, height: 20),
              NexusSpecRow('Total', '\$2,998.96', valueColor: NexusColors.cyan),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const NexusPrimaryButton(label: 'Confirmar pedido'),
        const SizedBox(height: 10),
        const NexusOutlineButton(
          label: 'Vaciar carrito',
          color: NexusColors.pink,
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _CartItemCard extends StatelessWidget {
  const _CartItemCard({
    required this.category,
    required this.icon,
    required this.gradientColors,
    required this.name,
    required this.unitPrice,
    required this.qty,
    required this.subtotal,
  });

  final String category;
  final IconData icon;
  final List<Color> gradientColors;
  final String name;
  final String unitPrice;
  final String qty;
  final String subtotal;

  @override
  Widget build(BuildContext context) {
    return NexusCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: NexusPlaceholderBox(
              icon: icon,
              gradientColors: gradientColors,
              height: 70,
              iconSize: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        category,
                        style: const TextStyle(
                          fontSize: 9,
                          color: NexusColors.textFaint,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {},
                      child: const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: NexusColors.pink,
                      ),
                    ),
                  ],
                ),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      unitPrice,
                      style: const TextStyle(
                        fontSize: 11,
                        color: NexusColors.textDim,
                      ),
                    ),
                    NexusQuantityStepper(
                      value: int.parse(qty),
                      compact: true,
                      onIncrement: () {},
                      onDecrement: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Subtotal',
                      style: TextStyle(
                        fontSize: 10,
                        color: NexusColors.textDim,
                      ),
                    ),
                    Text(
                      subtotal,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: NexusColors.cyan,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
