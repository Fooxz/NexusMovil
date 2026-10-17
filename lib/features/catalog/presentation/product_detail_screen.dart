import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/format_price.dart';
import '../../../routes.dart';
import '../../../theme/nexus_theme.dart';
import '../../../widgets/nexus_error_state.dart';
import '../../../widgets/nexus_loading.dart';
import '../../../widgets/nexus_page.dart';
import '../../../widgets/nexus_product_card.dart';
import '../../../widgets/nexus_quantity_stepper.dart';
import '../../../widgets/nexus_widgets.dart';
import '../catalog_providers.dart';
import '../domain/product.dart';
import 'product_visuals.dart';

class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productDetailProvider(productId));

    return NexusPage(
      title: 'DETALLES DEL PRODUCTO',
      showBack: true,
      children: [
        product.when(
          loading: () => const NexusLoading(),
          error: (error, stackTrace) => NexusErrorState(
            message: 'No se pudo cargar el producto.\n$error',
            onRetry: () => ref.invalidate(productDetailProvider(productId)),
          ),
          data: (product) => product == null
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Text(
                      'Producto no encontrado',
                      style: TextStyle(color: NexusColors.textDim),
                    ),
                  ),
                )
              : _ProductDetailContent(product: product),
        ),
      ],
    );
  }
}

class _ProductDetailContent extends ConsumerWidget {
  const _ProductDetailContent({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visuals = ProductVisuals.forCategory(product.category);
    final stockLabel = switch (product.stockLevel) {
      StockLevel.stable => 'EN STOCK',
      StockLevel.critical => 'CRÍTICO',
      StockLevel.outOfStock => ProductVisuals.stockLabel(product.stockLevel),
    };
    final stockColor = switch (product.stockLevel) {
      StockLevel.stable => NexusColors.green,
      StockLevel.critical => NexusColors.pink,
      StockLevel.outOfStock => ProductVisuals.stockColor(product.stockLevel),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Breadcrumb(
          categoryLabel: visuals.categoryLabel,
          productName: product.name,
        ),
        const SizedBox(height: 14),
        Container(
          height: 230,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: NexusColors.cyan.withValues(alpha: 0.5)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: visuals.gradientColors,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(visuals.icon, size: 64, color: NexusColors.cyan),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            NexusTag(product.brand),
            NexusTag(visuals.categoryLabel),
            NexusTag(stockLabel, color: stockColor),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          product.name,
          style: const TextStyle(
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
              formatPrice(product.priceCents),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: NexusColors.cyan,
              ),
            ),
            if (product.hasDiscount) ...[
              const SizedBox(width: 8),
              Text(
                formatPrice(product.oldPriceCents!),
                style: const TextStyle(
                  fontSize: 13,
                  color: NexusColors.textFaint,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              const SizedBox(width: 8),
              NexusDiscountBadge(label: '-${product.discountPercent}%'),
            ],
          ],
        ),
        if (product.quickSpecs.isNotEmpty) ...[
          const SizedBox(height: 18),
          const NexusUnderlineTitle('SPECS RÁPIDAS'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final spec in product.quickSpecs) NexusTag(spec),
            ],
          ),
        ],
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
        if (product.specs.isNotEmpty) ...[
          const SizedBox(height: 22),
          const NexusUnderlineTitle('ESPECIFICACIONES COMPLETAS'),
          const SizedBox(height: 4),
          NexusCard(
            child: Column(
              children: [
                NexusSpecRow('MARCA', product.brand),
                const Divider(color: NexusColors.border, height: 1),
                NexusSpecRow('CATEGORÍA', visuals.categoryLabel),
                const Divider(color: NexusColors.border, height: 1),
                NexusSpecRow(
                  'ESTADO',
                  stockLabel,
                  valueColor: stockColor,
                ),
                for (final spec in product.specs) ...[
                  const Divider(color: NexusColors.border, height: 1),
                  NexusSpecRow(spec.label, spec.value),
                ],
              ],
            ),
          ),
        ],
        _RelatedProducts(productId: product.id),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _RelatedProducts extends ConsumerWidget {
  const _RelatedProducts({required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final relatedProducts = ref.watch(relatedProductsProvider(productId));

    return relatedProducts.when(
      loading: () => const NexusLoading(),
      error: (error, stackTrace) => NexusErrorState(
        message: 'No se pudieron cargar productos relacionados.\n$error',
        onRetry: () => ref.invalidate(relatedProductsProvider(productId)),
      ),
      data: (products) {
        if (products.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 22),
            const NexusUnderlineTitle('TAMBIÉN TE PUEDE INTERESAR'),
            const SizedBox(height: 10),
            Row(
              children: [
                for (var index = 0; index < products.length; index++) ...[
                  if (index > 0) const SizedBox(width: 10),
                  Expanded(
                    child: _RelatedProductCard(product: products[index]),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }
}

class _RelatedProductCard extends StatelessWidget {
  const _RelatedProductCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final visuals = ProductVisuals.forCategory(product.category);

    return NexusProductCard(
      icon: visuals.icon,
      gradientColors: visuals.gradientColors,
      imageHeight: 74,
      tags: product.quickSpecs.isEmpty ? null : product.quickSpecs,
      name: product.name,
      priceCents: product.priceCents,
      priceFontSize: 11.5,
      onTap: () => Navigator.of(context).pushNamed(
        NexusRoutes.productDetail,
        arguments: product.id,
      ),
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({
    required this.categoryLabel,
    required this.productName,
  });

  final String categoryLabel;
  final String productName;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 9.5,
          color: NexusColors.textFaint,
          letterSpacing: 0.3,
        ),
        children: [
          TextSpan(text: 'INICIO > PRODUCTOS > $categoryLabel > '),
          TextSpan(
            text: productName,
            style: const TextStyle(
              color: NexusColors.cyan,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
