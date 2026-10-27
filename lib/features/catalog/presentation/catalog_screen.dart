import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/format_price.dart';
import '../../../routes.dart';
import '../../../theme/nexus_theme.dart';
import '../../../widgets/nexus_empty_state.dart';
import '../../../widgets/nexus_error_state.dart';
import '../../../widgets/nexus_loading.dart';
import '../../../widgets/nexus_page.dart';
import '../../../widgets/nexus_product_card.dart';
import '../../../widgets/nexus_widgets.dart';
import '../catalog_providers.dart';
import '../domain/product.dart';
import '../domain/product_filters.dart';
import '../../cart/presentation/cart_actions.dart';
import 'product_visuals.dart';

class CatalogScreen extends ConsumerWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 600) {
          unawaited(_requestNextPage(ref));
        }
        return false;
      },
      child: NexusPage.slivers(
        title: 'CATÁLOGO COMPLETO',
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.list(
              children: const [
                CatalogSearchField(),
                SizedBox(height: 14),
                CatalogCategoryChips(),
                SizedBox(height: 18),
                CatalogResultsHeader(),
                SizedBox(height: 12),
              ],
            ),
          ),
          _CatalogResults(),
        ],
      ),
    );
  }

  Future<void> _requestNextPage(WidgetRef ref) async {
    try {
      await ref.read(catalogControllerProvider.notifier).loadMore();
    } catch (_) {
      // The controller stores the failure in loadMoreError for the footer.
    }
  }
}

class CatalogSearchField extends ConsumerStatefulWidget {
  const CatalogSearchField({super.key});

  @override
  ConsumerState<CatalogSearchField> createState() => _CatalogSearchFieldState();
}

class _CatalogSearchFieldState extends ConsumerState<CatalogSearchField> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(
      catalogControllerProvider.select((value) => value.asData?.value.query),
      (previous, query) {
        if (query != null && query != _textController.text) {
          _textController.value = TextEditingValue(
            text: query,
            selection: TextSelection.collapsed(offset: query.length),
          );
        }
      },
    );

    return NexusTextField(
      hint: 'Buscar producto, marca o categoría',
      prefixIcon: Icons.search,
      controller: _textController,
      onChanged: ref.read(catalogControllerProvider.notifier).setSearch,
      textInputAction: TextInputAction.search,
    );
  }
}

/// Tipos de pieza (RF-033). "Todo" quita el filtro.
class CatalogCategoryChips extends ConsumerWidget {
  const CatalogCategoryChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(
      catalogControllerProvider.select(
        (value) => value.asData?.value.filters.category,
      ),
    );
    final controller = ref.read(catalogControllerProvider.notifier);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Todo'),
          selected: selected == null,
          onSelected: (_) => controller.setCategory(null),
        ),
        for (final category in ProductCategory.values)
          ChoiceChip(
            label: Text(ProductVisuals.chipLabel(category)),
            selected: selected == category,
            onSelected: (isSelected) =>
                controller.setCategory(isSelected ? category : null),
          ),
      ],
    );
  }
}

class CatalogResultsHeader extends ConsumerWidget {
  const CatalogResultsHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = ref.watch(
      catalogControllerProvider.select(
        (value) => value.asData?.value.total ?? 0,
      ),
    );

    return Row(
      children: [
        Expanded(
          child: Text(
            '$total productos',
            style: const TextStyle(fontSize: 12, color: NexusColors.textDim),
          ),
        ),
        const Flexible(child: CatalogFiltersButton()),
        const SizedBox(width: 8),
        const Flexible(child: CatalogSortMenu()),
      ],
    );
  }
}

class CatalogSortMenu extends ConsumerWidget {
  const CatalogSortMenu({super.key});

  static String label(ProductSort sort) => switch (sort) {
    ProductSort.relevance => 'Relevancia',
    ProductSort.priceAsc => 'Menor precio',
    ProductSort.priceDesc => 'Mayor precio',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sort = ref.watch(
      catalogControllerProvider.select(
        (value) => value.asData?.value.filters.sort ?? ProductSort.relevance,
      ),
    );

    return PopupMenuButton<ProductSort>(
      tooltip: 'Ordenar',
      initialValue: sort,
      onSelected: (value) =>
          ref.read(catalogControllerProvider.notifier).setSort(value),
      itemBuilder: (context) => [
        for (final option in ProductSort.values)
          PopupMenuItem(value: option, child: Text(label(option))),
      ],
      child: _HeaderPill(label: label(sort), icon: Icons.swap_vert),
    );
  }
}

/// Abre la hoja de marca y precio. Indica cuántos de esos filtros están activos.
class CatalogFiltersButton extends ConsumerWidget {
  const CatalogFiltersButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCount = ref.watch(
      catalogControllerProvider.select((value) {
        final filters = value.asData?.value.filters;
        if (filters == null) return 0;
        return (filters.brand != null ? 1 : 0) +
            (filters.minPriceCents != null || filters.maxPriceCents != null
                ? 1
                : 0);
      }),
    );

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        backgroundColor: NexusColors.bgAlt,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => const CatalogFiltersSheet(),
      ),
      child: _HeaderPill(
        label: activeCount == 0 ? 'Filtros' : 'Filtros ($activeCount)',
        icon: Icons.tune,
        highlighted: activeCount > 0,
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({
    required this.label,
    required this.icon,
    this.highlighted = false,
  });

  final String label;
  final IconData icon;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final color = highlighted ? NexusColors.cyan : NexusColors.textDim;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: highlighted ? NexusColors.cyan : NexusColors.border,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, color: color),
            ),
          ),
          const SizedBox(width: 4),
          Icon(icon, size: 16, color: color),
        ],
      ),
    );
  }
}

/// Rangos de precio sobre el precio de la mejor oferta, en centavos de COP.
const catalogPriceRanges = [
  (min: null, max: 100000000),
  (min: 100000000, max: 300000000),
  (min: 300000000, max: 600000000),
  (min: 600000000, max: null),
];

String catalogPriceRangeLabel(({int? min, int? max}) range) =>
    switch (range) {
      (min: null, max: final int max) => 'Hasta ${formatPrice(max)}',
      (min: final int min, max: null) => 'Más de ${formatPrice(min)}',
      (min: final int min, max: final int max) =>
        '${formatPrice(min)} – ${formatPrice(max)}',
      _ => 'Cualquier precio',
    };

/// Filtros por marca y precio. Cada selección se aplica de inmediato.
class CatalogFiltersSheet extends ConsumerWidget {
  const CatalogFiltersSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(
      catalogControllerProvider.select(
        (value) => value.asData?.value.filters ?? const ProductFilters(),
      ),
    );
    final brands = ref.watch(catalogBrandsProvider);
    final controller = ref.read(catalogControllerProvider.notifier);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const NexusUnderlineTitle('MARCA'),
            const SizedBox(height: 10),
            brands.when(
              loading: () => const NexusLoading(),
              error: (error, _) => NexusErrorState(
                message: 'No se pudieron cargar las marcas.\n$error',
                onRetry: () => ref.invalidate(catalogBrandsProvider),
              ),
              data: (brands) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Todas'),
                    selected: filters.brand == null,
                    onSelected: (_) => controller.setBrand(null),
                  ),
                  for (final brand in brands)
                    ChoiceChip(
                      label: Text(brand),
                      selected: filters.brand == brand,
                      onSelected: (selected) =>
                          controller.setBrand(selected ? brand : null),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const NexusUnderlineTitle('PRECIO'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Cualquier precio'),
                  selected:
                      filters.minPriceCents == null &&
                      filters.maxPriceCents == null,
                  onSelected: (_) => controller.setPriceRange(),
                ),
                for (final range in catalogPriceRanges)
                  ChoiceChip(
                    label: Text(catalogPriceRangeLabel(range)),
                    selected:
                        filters.minPriceCents == range.min &&
                        filters.maxPriceCents == range.max,
                    onSelected: (selected) => selected
                        ? controller.setPriceRange(
                            minPriceCents: range.min,
                            maxPriceCents: range.max,
                          )
                        : controller.setPriceRange(),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            NexusPrimaryButton(
              label: 'VER RESULTADOS',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogResults extends ConsumerWidget {
  const _CatalogResults();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogControllerProvider);

    return catalog.when(
      loading: () => SliverToBoxAdapter(
        child: Column(
          children: [
            const NexusLoading(),
            TextButton(
              onPressed: () =>
                  ref.read(catalogControllerProvider.notifier).clearFilters(),
              child: const Text('Limpiar filtros'),
            ),
          ],
        ),
      ),
      error: (error, stackTrace) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              NexusErrorState(
                message: 'No se pudo cargar el catálogo.\n$error',
                onRetry: () =>
                    ref.read(catalogControllerProvider.notifier).retry(),
              ),
              TextButton(
                onPressed: () =>
                    ref.read(catalogControllerProvider.notifier).clearFilters(),
                child: const Text('Limpiar filtros'),
              ),
            ],
          ),
        ),
      ),
      data: (state) {
        if (state.items.isEmpty) {
          return SliverToBoxAdapter(
            child: NexusEmptyState(
              message: 'No se encontraron productos.',
              actionLabel: 'Limpiar filtros',
              onAction: () =>
                  ref.read(catalogControllerProvider.notifier).clearFilters(),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverMainAxisGroup(
            slivers: [
              SliverGrid.builder(
                itemCount: state.items.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  // 0.70 deja aire suficiente para teléfonos de 360 px.
                  childAspectRatio: 0.70,
                ),
                itemBuilder: (context, index) => _CatalogProductCard(
                  key: ValueKey(state.items[index].id),
                  product: state.items[index],
                ),
              ),
              SliverToBoxAdapter(
                child: _CatalogListFooter(
                  state: state,
                  onRetry: () => _requestNextPage(ref),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _requestNextPage(WidgetRef ref) async {
    try {
      await ref.read(catalogControllerProvider.notifier).loadMore();
    } catch (_) {
      // The controller stores the failure in loadMoreError for the footer.
    }
  }
}

class _CatalogListFooter extends StatelessWidget {
  const _CatalogListFooter({required this.state, required this.onRetry});

  final CatalogState state;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Column(
            children: [
              Text(
                'No se pudieron cargar más productos.\n${state.loadMoreError}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: NexusColors.textDim),
              ),
              TextButton(
                onPressed: () => unawaited(onRetry()),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    if (!state.hasMore) return const SizedBox(height: 20);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: TextButton(
          onPressed: () => unawaited(onRetry()),
          child: const Text('Cargar más'),
        ),
      ),
    );
  }
}

class _CatalogProductCard extends StatelessWidget {
  const _CatalogProductCard({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final visuals = ProductVisuals.forCategory(product.category);

    return NexusProductCard(
      imageUrl: product.imageUrl,
      icon: visuals.icon,
      gradientColors: visuals.gradientColors,
      discountLabel: product.hasDiscount
          ? '-${product.discountPercent}%'
          : null,
      brand: '${product.brand} / ${visuals.shortCategoryLabel}',
      status: ProductVisuals.stockLabel(product.stockLevel),
      statusColor: ProductVisuals.stockColor(product.stockLevel),
      name: product.name,
      specs: product.summary,
      oldPriceCents: product.hasDiscount ? product.oldPriceCents : null,
      priceCents: product.priceCents,
      onTap: () =>
          Navigator.of(context)
              .pushNamed(NexusRoutes.productDetail, arguments: product.id),
      actions: _CardActions(product: product),
    );
  }
}

/// "Ver" y agregar al carrito la mejor oferta (`bestOfferId`). Sin stock o
/// sin oferta, el botón del carrito queda deshabilitado.
class _CardActions extends ConsumerWidget {
  const _CardActions({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offerId = product.bestOfferId;
    final canAdd =
        offerId != null && product.stockLevel != StockLevel.outOfStock;

    return Row(
      children: [
        Expanded(
          child: NexusOutlineButton(
            label: 'Ver',
            onPressed: () => Navigator.of(
              context,
            ).pushNamed(NexusRoutes.productDetail, arguments: product.id),
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
        Tooltip(
          message: canAdd ? 'Agregar al carrito' : 'Sin stock',
          child: InkWell(
            onTap: canAdd
                ? () => addToCart(context, ref, offerId: offerId)
                : null,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: canAdd ? NexusColors.cyan : NexusColors.border,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.shopping_cart,
                size: 15,
                color: canAdd ? NexusColors.onCyan : NexusColors.textFaint,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
