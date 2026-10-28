import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/format_price.dart';
import '../../../theme/nexus_theme.dart';
import '../../../widgets/nexus_error_state.dart';
import '../../../widgets/nexus_loading.dart';
import '../../../widgets/nexus_page.dart';
import '../../../widgets/nexus_widgets.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../../catalog/presentation/product_visuals.dart';
import '../domain/portal_models.dart';
import '../provider_portal_providers.dart';
import 'offer_form_screen.dart';
import 'portal_widgets.dart';
import 'product_form_screen.dart';

/// Una publicación de la tienda: su oferta (precio, descuento, stock y
/// estado) y la ficha. La ficha solo se edita si la registró la tienda y
/// ninguna otra la vende.
class MyOfferScreen extends ConsumerWidget {
  const MyOfferScreen({super.key, required this.productId});

  final String productId;

  Future<void> _retire(BuildContext context, WidgetRef ref, MyOfferDetail detail) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirar publicación'),
        content: Text(
          '"${detail.offer.name}" dejará de verse en el catálogo. Podrás volver a publicarla después.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Retirar')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final result = await ref
        .read(portalActionControllerProvider.notifier)
        .run((repository) => repository.retireOffer(productId));
    if (!context.mounted) return;
    final error = ref.read(portalActionControllerProvider).error;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(result != null ? 'Publicación retirada.' : AuthErrorBanner.messageFor(error ?? Object())),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(myOfferDetailProvider(productId));
    // Mantiene vivo el controlador de acciones mientras se retira.
    final action = ref.watch(portalActionControllerProvider);

    return NexusPage(
      title: 'PUBLICACIÓN',
      showBack: true,
      showCart: false,
      children: [
        detail.when(
          loading: () => const NexusLoading(),
          error: (error, _) => NexusErrorState(
            message: 'No se pudo cargar la publicación.\n${AuthErrorBanner.messageFor(error)}',
            onRetry: () => ref.invalidate(myOfferDetailProvider(productId)),
          ),
          data: (detail) {
            final offer = detail.offer;
            final visuals = ProductVisuals.forCategory(offer.category);
            final retired = offer.status == OfferStatus.retired;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  offer.name,
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  [offer.brand, offer.model, visuals.categoryLabel].whereType<String>().join(' · '),
                  style: const TextStyle(fontSize: 12, color: NexusColors.textDim),
                ),
                const SizedBox(height: 14),
                const NexusUnderlineTitle('TU OFERTA'),
                const SizedBox(height: 4),
                NexusCard(
                  child: Column(
                    children: [
                      NexusSpecRow('PRECIO', formatPrice(offer.priceCents)),
                      const Divider(color: NexusColors.border, height: 1),
                      NexusSpecRow(
                        'PRECIO ANTERIOR',
                        offer.oldPriceCents == null ? 'Sin descuento' : formatPrice(offer.oldPriceCents!),
                      ),
                      const Divider(color: NexusColors.border, height: 1),
                      NexusSpecRow('EXISTENCIAS', '${offer.stockUnits} unidades'),
                      const Divider(color: NexusColors.border, height: 1),
                      NexusSpecRow('ESTADO', offerStatusLabel(offer.status), valueColor: offerStatusColor(offer.status)),
                      const Divider(color: NexusColors.border, height: 1),
                      NexusSpecRow('EN EL CATÁLOGO', offer.visible ? 'Visible' : 'No visible'),
                      const Divider(color: NexusColors.border, height: 1),
                      NexusSpecRow('CÓDIGO INTERNO', offer.externalSku),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  detail.sellers <= 1
                      ? 'Por ahora solo tu tienda vende este producto.'
                      : '${detail.sellers} tiendas venden este producto: cada una tiene su tarjeta en el catálogo.',
                  style: const TextStyle(fontSize: 11.5, color: NexusColors.textDim),
                ),
                const SizedBox(height: 14),
                if (retired)
                  NexusPrimaryButton(
                    label: 'VOLVER A PUBLICAR',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => OfferFormScreen(productId: productId, productName: offer.name),
                      ),
                    ),
                  )
                else
                  NexusPrimaryButton(
                    label: 'EDITAR OFERTA',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => OfferFormScreen(
                          productId: productId,
                          productName: offer.name,
                          current: offer,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                if (offer.canEditSheet)
                  NexusOutlineButton(
                    label: 'EDITAR FICHA DEL PRODUCTO',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => ProductFormScreen.edit(current: detail)),
                    ),
                  )
                else
                  const Text(
                    'La ficha es compartida: otras tiendas pueden venderla, así que solo cambias tu oferta. '
                    'Si tiene un error, escribe a NEXUS.',
                    style: TextStyle(fontSize: 11.5, color: NexusColors.textDim),
                  ),
                if (!retired) ...[
                  const SizedBox(height: 10),
                  NexusOutlineButton(
                    label: action.isLoading ? 'RETIRANDO...' : 'RETIRAR PUBLICACIÓN',
                    color: NexusColors.pink,
                    borderColor: NexusColors.pink,
                    onPressed: action.isLoading ? null : () => _retire(context, ref, detail),
                  ),
                ],
                const SizedBox(height: 20),
              ],
            );
          },
        ),
      ],
    );
  }
}
