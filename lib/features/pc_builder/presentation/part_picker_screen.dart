import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/format_price.dart';
import '../../../theme/nexus_theme.dart';
import '../../../widgets/nexus_empty_state.dart';
import '../../../widgets/nexus_error_state.dart';
import '../../../widgets/nexus_loading.dart';
import '../../../widgets/nexus_page.dart';
import '../../../widgets/nexus_product_image.dart';
import '../../../widgets/nexus_widgets.dart';
import '../../cart/presentation/cart_actions.dart';
import '../../catalog/domain/product.dart';
import '../../catalog/presentation/product_visuals.dart';
import '../domain/pc_builder_models.dart';
import '../pc_builder_providers.dart';

/// Piezas para una ranura (RF-049): primero las compatibles con lo ya elegido
/// y con stock. Las incompatibles explican por qué no sirven.
class PartPickerScreen extends ConsumerWidget {
  const PartPickerScreen({super.key, required this.slot});

  final BuilderSlot slot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidates = ref.watch(builderCandidatesProvider(slot.category));
    final selectedOfferId = ref.watch(
      pcBuilderControllerProvider.select(
        (state) => state.value?.selection[slot.category],
      ),
    );

    return NexusPage.slivers(
      title: slot.label.toUpperCase(),
      showBack: true,
      showCart: false,
      slivers: [
        switch (candidates) {
          AsyncValue(value: final items?) when items.isEmpty =>
            const SliverToBoxAdapter(
              child: NexusEmptyState(message: 'No hay piezas de este tipo por ahora.'),
            ),
          AsyncValue(value: final items?) => SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.builder(
              itemCount: items.length,
              itemBuilder: (context, index) => _CandidateCard(
                key: ValueKey(items[index].product.id),
                slot: slot,
                candidate: items[index],
                selected: items[index].product.bestOfferId == selectedOfferId,
              ),
            ),
          ),
          AsyncValue(:final error?) => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: NexusErrorState(
                message: 'No se pudieron cargar las piezas.\n${cartErrorMessage(error)}',
                onRetry: () => ref.invalidate(builderCandidatesProvider(slot.category)),
              ),
            ),
          ),
          _ => const SliverToBoxAdapter(child: NexusLoading()),
        },
      ],
    );
  }
}

class _CandidateCard extends ConsumerWidget {
  const _CandidateCard({
    super.key,
    required this.slot,
    required this.candidate,
    required this.selected,
  });

  final BuilderSlot slot;
  final BuilderCandidate candidate;
  final bool selected;

  Future<void> _choose(BuildContext context, WidgetRef ref) async {
    final offerId = candidate.product.bestOfferId;
    if (offerId == null) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(pcBuilderControllerProvider.notifier).select(slot.category, offerId);
      navigator.pop();
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(cartErrorMessage(error))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = candidate.product;
    final visuals = ProductVisuals.forCategory(product.category);
    final canChoose = candidate.inStock && product.bestOfferId != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: NexusColors.card,
          border: Border.all(
            color: selected ? NexusColors.cyan : NexusColors.border,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 56,
                  child: NexusProductImage(
                    imageUrl: product.imageUrl,
                    icon: visuals.icon,
                    gradientColors: visuals.gradientColors,
                    height: 56,
                    borderRadius: 8,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (product.summary case final summary?)
                        Text(
                          summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10.5, color: NexusColors.textDim),
                        ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (selected) const NexusTag('ELEGIDA', color: NexusColors.cyan),
                          if (candidate.compatible)
                            const NexusTag('COMPATIBLE', color: NexusColors.green)
                          else
                            const NexusTag('NO COMPATIBLE', color: NexusColors.pink),
                          if (!candidate.inStock)
                            NexusTag(StockLevel.outOfStock.tagLabel),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatPrice(product.priceCents),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: NexusColors.cyan,
                  ),
                ),
              ],
            ),
            if (candidate.incompatibilityReason case final reason?)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  reason,
                  style: const TextStyle(fontSize: 11.5, color: NexusColors.pink),
                ),
              ),
            const SizedBox(height: 8),
            NexusPrimaryButton(
              label: selected ? 'ELEGIDA' : 'ELEGIR',
              enabled: canChoose && !selected,
              fullWidth: true,
              fontSize: 11,
              padding: const EdgeInsets.symmetric(vertical: 10),
              color: candidate.compatible ? NexusColors.cyan : NexusColors.border,
              foregroundColor: candidate.compatible ? NexusColors.onCyan : NexusColors.text,
              onPressed: () => _choose(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}
