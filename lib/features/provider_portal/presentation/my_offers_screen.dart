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
import '../../auth/presentation/auth_widgets.dart';
import '../../catalog/presentation/product_visuals.dart';
import '../domain/portal_models.dart';
import '../provider_portal_providers.dart';
import 'my_offer_screen.dart';
import 'portal_widgets.dart';
import 'sell_product_screen.dart';

/// Pestaña PUBLICACIONES de la tienda: sus ofertas, con su precio, su stock y
/// su estado, y el acceso para publicar un producto.
class MyOffersScreen extends ConsumerWidget {
  const MyOffersScreen({super.key});

  static const _filters = <(String, OfferStatus?)>[
    ('Activas', null),
    ('Publicadas', OfferStatus.published),
    ('Pausadas', OfferStatus.paused),
    ('Borradores', OfferStatus.draft),
    ('Retiradas', OfferStatus.retired),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(myOffersStatusProvider);
    final offers = ref.watch(myOffersControllerProvider);

    return NexusPage(
      title: 'MIS PUBLICACIONES',
      showCart: false,
      children: [
        NexusPrimaryButton(
          label: 'PUBLICAR UN PRODUCTO',
          icon: Icons.add,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SellProductScreen()),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (label, value) in _filters)
              ChoiceChip(
                label: Text(label),
                selected: status == value,
                onSelected: (_) => ref.read(myOffersStatusProvider.notifier).select(value),
              ),
          ],
        ),
        const SizedBox(height: 14),
        offers.when(
          loading: () => const NexusLoading(),
          error: (error, _) => NexusErrorState(
            message: 'No se pudieron cargar tus publicaciones.\n${AuthErrorBanner.messageFor(error)}',
            onRetry: () => ref.invalidate(myOffersControllerProvider),
          ),
          data: (state) {
            if (state.items.isEmpty) {
              return const NexusEmptyState(
                message: 'No tienes publicaciones con este estado.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  state.total == 1 ? '1 publicación' : '${state.total} publicaciones',
                  style: const TextStyle(fontSize: 12, color: NexusColors.textDim),
                ),
                const SizedBox(height: 8),
                for (final offer in state.items) _MyOfferTile(key: ValueKey(offer.offerId), offer: offer),
                if (state.hasMore)
                  TextButton(
                    onPressed: state.isLoadingMore
                        ? null
                        : () => ref.read(myOffersControllerProvider.notifier).loadMore(),
                    child: Text(state.isLoadingMore ? 'Cargando...' : 'Cargar más'),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _MyOfferTile extends StatelessWidget {
  const _MyOfferTile({super.key, required this.offer});

  final MyOffer offer;

  @override
  Widget build(BuildContext context) {
    final visuals = ProductVisuals.forCategory(offer.category);
    final hasDiscount = offer.oldPriceCents != null && offer.oldPriceCents! > offer.priceCents;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => MyOfferScreen(productId: offer.productId)),
        ),
        child: NexusCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 64,
                  child: NexusProductImage(
                    imageUrl: offer.imageUrl,
                    icon: visuals.icon,
                    gradientColors: visuals.gradientColors,
                    height: 64,
                    borderRadius: 8,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${offer.brand} · ${visuals.shortCategoryLabel}',
                        style: const TextStyle(fontSize: 11, color: NexusColors.textDim),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            formatPrice(offer.priceCents),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: NexusColors.cyan),
                          ),
                          if (hasDiscount)
                            Text(
                              formatPrice(offer.oldPriceCents!),
                              style: const TextStyle(
                                fontSize: 11,
                                color: NexusColors.textFaint,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          NexusTag(offerStatusLabel(offer.status), color: offerStatusColor(offer.status)),
                          NexusTag(
                            offer.stockUnits == 1 ? '1 unidad' : '${offer.stockUnits} unidades',
                            color: ProductVisuals.stockColor(offer.stockLevel),
                          ),
                          if (offer.moderation != OfferModeration.approved)
                            NexusTag(offer.moderation.label.toUpperCase(), color: NexusColors.pink)
                          else if (offer.status == OfferStatus.published && !offer.visible)
                            const NexusTag('NO VISIBLE', color: NexusColors.pink),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
