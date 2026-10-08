// lib/screens/catalog/product_detail_screen.dart
//
// Detalle de producto. Muestra un producto fijo (RTX 5090) a modo de
// mockup: cuando el catálogo esté conectado a datos reales, esta pantalla
// recibirá el producto seleccionado como argumento de la ruta.

import 'package:flutter/material.dart';

import '../../core/utils/format_price.dart';
import '../../theme/nexus_theme.dart';
import '../../widgets/nexus_bottom_nav.dart';
import '../../widgets/nexus_page.dart';
import '../../widgets/nexus_product_card.dart';
import '../../widgets/nexus_quantity_stepper.dart';
import '../../widgets/nexus_widgets.dart';

class ProductDetailScreen extends StatelessWidget {
  const ProductDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return NexusPage(
      title: 'DETALLES DEL PRODUCTO',
      showBack: true,
      bottomNavigationBar: const NexusBottomNav(currentIndex: 1),
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
          child: const Icon(
            Icons.videogame_asset,
            size: 64,
            color: NexusColors.cyan,
          ),
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
            Text(
              formatPrice(199900),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: NexusColors.cyan,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatPrice(229900),
              style: TextStyle(
                fontSize: 13,
                color: NexusColors.textFaint,
                decoration: TextDecoration.lineThrough,
              ),
            ),
            const SizedBox(width: 8),
            const NexusDiscountBadge(label: '-13%'),
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
            NexusQuantityStepper(
              value: 1,
              onIncrement: () {},
              onDecrement: () {},
            ),
            const SizedBox(width: 8),
            Expanded(
              child: NexusPrimaryButton(
                label: 'COMPRAR AHORA',
                onPressed: () {},
                color: NexusColors.pink,
                foregroundColor: Colors.white,
                fullWidth: false,
                fontSize: 10.5,
                padding: const EdgeInsets.symmetric(vertical: 13),
                borderRadius: 8,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: NexusPrimaryButton(
                label: 'AGREGAR AL CARRITO',
                onPressed: () {},
                color: NexusColors.cyan,
                foregroundColor: NexusColors.onCyan,
                icon: Icons.shopping_cart,
                fullWidth: false,
                fontSize: 9,
                padding: const EdgeInsets.symmetric(
                  vertical: 13,
                  horizontal: 4,
                ),
                borderRadius: 8,
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
              child: NexusProductCard(
                icon: Icons.videogame_asset_outlined,
                gradientColors: [Color(0xFF141414), Color(0xFF23364A)],
                imageHeight: 74,
                tags: ['RTX 5080', '16GB'],
                name: 'NVIDIA RTX 5080',
                priceCents: 169900,
                priceFontSize: 11.5,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: NexusProductCard(
                icon: Icons.ac_unit,
                gradientColors: [Color(0xFF141414), Color(0xFF3A1030)],
                imageHeight: 74,
                tags: ['LIQUID', '360MM'],
                name: 'Cooler Master Elite Liquid 360',
                priceCents: 24900,
                priceFontSize: 11.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb();

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: const TextSpan(
        style: TextStyle(
          fontSize: 9.5,
          color: NexusColors.textFaint,
          letterSpacing: 0.3,
        ),
        children: [
          TextSpan(text: 'INICIO > PRODUCTOS > TARJETAS GRÁFICAS > '),
          TextSpan(
            text: 'RTX 5090',
            style: TextStyle(
              color: NexusColors.cyan,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
