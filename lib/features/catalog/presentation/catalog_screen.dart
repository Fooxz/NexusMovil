import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../routes.dart';
import '../../../theme/nexus_theme.dart';
import '../../../widgets/nexus_error_state.dart';
import '../../../widgets/nexus_page.dart';
import '../../../widgets/nexus_product_card.dart';
import '../../../widgets/nexus_widgets.dart';
import '../../../widgets/nexus_loading.dart';
import '../catalog_providers.dart';
import '../domain/product.dart';
import 'product_visuals.dart';

class CatalogScreen extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogPage = ref.watch(catalogPageProvider);

    return NexusPage(
      title: 'CATÁLOGO COMPLETO',
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
                  for (final filter in _primaryFilters)
                    _FilterChip(label: filter, active: filter == 'Celular'),
                  for (final filter in _secondaryFilters)
                    _FilterChip(label: filter),
                ],
              ),
              const SizedBox(height: 18),
              catalogPage.when(
                loading: () => const NexusLoading(),
                error: (error, stackTrace) => NexusErrorState(
                  message: 'No se pudo cargar el catálogo.\n$error',
                  onRetry: () => ref.invalidate(catalogPageProvider),
                ),
                data: (page) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${page.total} productos',
                          style: const TextStyle(
                            fontSize: 12,
                            color: NexusColors.textDim,
                          ),
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
                        for (final product in page.items)
                          _CatalogProductCard(product: product),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }
}

class _CatalogProductCard extends StatelessWidget {
  const _CatalogProductCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final visuals = ProductVisuals.forCategory(product.category);
    final isCritical = product.stockLevel == StockLevel.critical;

    return NexusProductCard(
      icon: visuals.icon,
      gradientColors: visuals.gradientColors,
      discountLabel: product.hasDiscount
          ? '-${product.discountPercent}%'
          : null,
      brand: '${product.brand} / ${visuals.shortCategoryLabel}',
      status: isCritical ? 'CRÍTICO' : 'ESTABLE',
      statusColor: isCritical ? NexusColors.pink : NexusColors.cyan,
      name: product.name,
      specs: product.summary,
      oldPriceCents: product.hasDiscount ? product.oldPriceCents : null,
      priceCents: product.priceCents,
      onTap: () => Navigator.of(context).pushNamed(
        NexusRoutes.productDetail,
        arguments: product.id,
      ),
      actions: _productActions(context, product.id),
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

Widget _productActions(BuildContext context, String productId) {
  return Row(
    children: [
      Expanded(
        child: NexusOutlineButton(
          label: 'Ver',
          onPressed: () => Navigator.of(context).pushNamed(
            NexusRoutes.productDetail,
            arguments: productId,
          ),
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
