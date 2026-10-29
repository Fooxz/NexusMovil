import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../routes.dart';
import '../../../theme/nexus_theme.dart';
import '../../../widgets/nexus_product_card.dart';
import '../../../widgets/nexus_widgets.dart';
import '../../account/account_providers.dart';
import '../../cart/presentation/cart_actions.dart';
import '../domain/catalog_offer.dart';
import '../domain/product.dart';
import 'product_detail_screen.dart';
import 'product_visuals.dart';

/// Tarjeta de la oferta de UNA tienda: su nombre, su precio, su descuento y
/// su stock (API_CONTRATO, parte 6). La usan el catálogo, el inicio y el
/// catálogo de cada tienda. Con [showSeller] en falso no repite la tienda
/// (dentro de su propio catálogo).
class CatalogOfferCard extends StatelessWidget {
  const CatalogOfferCard({super.key, required this.offer, this.showSeller = true});

  final CatalogOffer offer;
  final bool showSeller;

  void _openDetail(BuildContext context) => Navigator.of(context).pushNamed(
    NexusRoutes.productDetail,
    arguments: ProductDetailArgs(offer.productId, offerId: offer.offerId),
  );

  @override
  Widget build(BuildContext context) {
    final visuals = ProductVisuals.forCategory(offer.category);

    return NexusProductCard(
      imageUrl: offer.imageUrl,
      icon: visuals.icon,
      gradientColors: visuals.gradientColors,
      discountLabel: offer.hasDiscount ? '-${offer.discountPercent}%' : null,
      brand: '${offer.brand} / ${visuals.shortCategoryLabel}',
      status: ProductVisuals.stockLabel(offer.stockLevel),
      statusColor: ProductVisuals.stockColor(offer.stockLevel),
      name: offer.name,
      specs: offer.summary,
      seller: showSeller ? offer.providerName : null,
      sellerNote: showSeller && offer.offerCount > 1 ? 'Comparar ${offer.offerCount}' : null,
      oldPriceCents: offer.hasDiscount ? offer.oldPriceCents : null,
      priceCents: offer.priceCents,
      onTap: () => _openDetail(context),
      actions: _CardActions(offer: offer, onOpen: () => _openDetail(context)),
    );
  }
}

/// "Ver" y agregar al carrito la oferta de esta tarjeta. Sin stock, el botón
/// del carrito queda deshabilitado; las cuentas que no compran no lo ven.
class _CardActions extends ConsumerWidget {
  const _CardActions({required this.offer, required this.onOpen});

  final CatalogOffer offer;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canAdd = offer.stockLevel != StockLevel.outOfStock;
    final accountCanBuy = ref.watch(canBuyProvider);

    return Row(
      children: [
        Expanded(
          child: NexusOutlineButton(
            label: 'Ver',
            onPressed: onOpen,
            color: NexusColors.text,
            borderColor: NexusColors.border,
            compact: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            fontSize: 10.5,
            borderRadius: 6,
            bold: false,
          ),
        ),
        if (accountCanBuy) ...[
          const SizedBox(width: 6),
          Tooltip(
            message: canAdd ? 'Agregar al carrito' : 'Sin stock',
            child: InkWell(
              onTap: canAdd
                  ? () => addToCart(context, ref, offerId: offer.offerId, productName: offer.name)
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
      ],
    );
  }
}
