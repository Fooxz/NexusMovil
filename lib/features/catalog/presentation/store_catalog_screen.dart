import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/nexus_theme.dart';
import '../../../widgets/nexus_empty_state.dart';
import '../../../widgets/nexus_error_state.dart';
import '../../../widgets/nexus_loading.dart';
import '../../../widgets/nexus_page.dart';
import '../../../widgets/nexus_widgets.dart';
import '../catalog_providers.dart';
import '../domain/product.dart';
import 'catalog_offer_card.dart';
import 'product_visuals.dart';

/// Argumentos de `NexusRoutes.store`: la tienda y su nombre visible, que se
/// muestra mientras carga su catálogo.
class StoreCatalogArgs {
  const StoreCatalogArgs(this.storeId, this.storeName);

  final String storeId;
  final String storeName;
}

/// Catálogo de UNA tienda: todas sus piezas visibles, con búsqueda y tipo de
/// pieza. Se abre desde "Vendido por" en el detalle de un producto.
class StoreCatalogScreen extends ConsumerStatefulWidget {
  const StoreCatalogScreen({super.key, required this.storeId, required this.storeName});

  final String storeId;
  final String storeName;

  @override
  ConsumerState<StoreCatalogScreen> createState() => _StoreCatalogScreenState();
}

class _StoreCatalogScreenState extends ConsumerState<StoreCatalogScreen> {
  Timer? _debounce;

  StoreCatalogController get _controller => ref.read(storeCatalogProvider(widget.storeId).notifier);

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _controller.setFilters(search: text));
  }

  Future<void> _loadMore() async {
    try {
      await _controller.loadMore();
    } catch (_) {
      // El botón "Cargar más" sigue visible para reintentar.
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(storeCatalogProvider(widget.storeId));
    final pageSize = ref.watch(catalogPageSizeProvider);
    final category = catalog.value?.filters.category;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 600) unawaited(_loadMore());
        return false;
      },
      child: NexusPage.slivers(
        title: 'TIENDA',
        showBack: true,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.list(
              children: [
                _StoreHeader(name: widget.storeName, total: catalog.value?.total),
                const SizedBox(height: 14),
                NexusTextField(
                  hint: 'Buscar en ${widget.storeName}',
                  prefixIcon: Icons.search,
                  onChanged: _onSearch,
                  textInputAction: TextInputAction.search,
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: const Text('Todo'),
                          selected: category == null,
                          onSelected: (_) => _controller.setFilters(category: null),
                        ),
                      ),
                      for (final option in ProductCategory.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(ProductVisuals.chipLabel(option)),
                            selected: category == option,
                            onSelected: (selected) => _controller.setFilters(category: selected ? option : null),
                          ),
                        ),
                    ],
                  ),
                ),
                if (catalog.value?.isRefreshing ?? false)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: LinearProgressIndicator(color: NexusColors.cyan, minHeight: 2),
                  ),
                const SizedBox(height: 14),
              ],
            ),
          ),
          switch (catalog) {
            AsyncValue(value: final state?) when state.items.isEmpty => const SliverToBoxAdapter(
              child: NexusEmptyState(message: 'Esta tienda no tiene piezas con ese filtro.'),
            ),
            AsyncValue(value: final state?) => SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverMainAxisGroup(
                slivers: [
                  SliverGrid.builder(
                    itemCount: state.items.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.66,
                    ),
                    itemBuilder: (context, index) => CatalogOfferCard(
                      key: ValueKey(state.items[index].offerId),
                      offer: state.items[index],
                      showSeller: false,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: state.isLoadingMore
                          ? const Center(child: CircularProgressIndicator())
                          : state.hasMoreWith(pageSize)
                          ? Center(child: TextButton(onPressed: _loadMore, child: const Text('Cargar más')))
                          : const SizedBox(height: 4),
                    ),
                  ),
                ],
              ),
            ),
            AsyncValue(:final error?) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: NexusErrorState(
                  message: 'No se pudo cargar el catálogo de la tienda.\n$error',
                  onRetry: () => ref.invalidate(storeCatalogProvider(widget.storeId)),
                ),
              ),
            ),
            _ => const SliverToBoxAdapter(child: NexusLoading()),
          },
        ],
      ),
    );
  }
}

class _StoreHeader extends StatelessWidget {
  const _StoreHeader({required this.name, required this.total});

  final String name;
  final int? total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF1C3A40), Color(0xFF0D1418), Color(0xFF0A0C0F)],
        ),
        border: Border.all(color: NexusColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: NexusColors.cyan.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: NexusColors.cyan.withValues(alpha: 0.5)),
            ),
            alignment: Alignment.center,
            child: Text(
              name.isEmpty ? '?' : name.characters.first.toUpperCase(),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: NexusColors.cyan),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.verified, size: 14, color: NexusColors.cyan),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        total == null
                            ? 'Tienda verificada por NEXUS'
                            : 'Tienda verificada · ${total == 1 ? '1 pieza' : '$total piezas'}',
                        style: const TextStyle(fontSize: 11.5, color: NexusColors.textDim),
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
