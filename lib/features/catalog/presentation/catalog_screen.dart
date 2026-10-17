import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class CatalogCategoryChips extends ConsumerWidget {
  const CatalogCategoryChips({super.key});

  static const _categories = [
    (label: 'CPU', category: ProductCategory.cpu),
    (label: 'GPU', category: ProductCategory.gpu),
    (label: 'RAM', category: ProductCategory.ram),
    (label: 'Motherboard', category: ProductCategory.motherboard),
    (label: 'Almacenamiento', category: ProductCategory.storage),
    (label: 'Fuente', category: ProductCategory.psu),
    (label: 'Gabinete', category: ProductCategory.pcCase),
    (label: 'Refrigeración', category: ProductCategory.cooling),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategory = ref.watch(
      catalogControllerProvider.select((value) => value.asData?.value.category),
    );

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in _categories)
          ChoiceChip(
            label: Text(item.label),
            selected: selectedCategory == item.category,
            onSelected: (selected) {
              ref
                  .read(catalogControllerProvider.notifier)
                  .setCategory(selected ? item.category : null);
            },
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
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$total productos',
          style: const TextStyle(fontSize: 12, color: NexusColors.textDim),
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
              Icon(
                Icons.keyboard_arrow_down,
                size: 16,
                color: NexusColors.textDim,
              ),
            ],
          ),
        ),
      ],
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
                  childAspectRatio: 0.72,
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
      actions: _productActions(context, product.id),
    );
  }
}

Widget _productActions(BuildContext context, String productId) {
  return Row(
    children: [
      Expanded(
        child: NexusOutlineButton(
          label: 'Ver',
          onPressed: () =>
              Navigator.of(context)
                  .pushNamed(NexusRoutes.productDetail, arguments: productId),
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
