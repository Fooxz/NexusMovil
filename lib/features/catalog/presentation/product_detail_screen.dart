import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/format_price.dart';
import '../../../routes.dart';
import '../../../theme/nexus_theme.dart';
import '../../../widgets/nexus_error_state.dart';
import '../../../widgets/nexus_loading.dart';
import '../../../widgets/nexus_page.dart';
import '../../../widgets/nexus_product_card.dart';
import '../../../widgets/nexus_product_image.dart';
import '../../../widgets/nexus_quantity_stepper.dart';
import '../../../widgets/nexus_widgets.dart';
import '../catalog_providers.dart';
import '../domain/product.dart';
import '../../cart/presentation/cart_actions.dart';
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
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: NexusColors.cyan.withValues(alpha: 0.5)),
          ),
          child: NexusProductImage(
            imageUrl: product.imageUrl,
            icon: visuals.icon,
            iconColor: NexusColors.cyan,
            iconSize: 64,
            gradientColors: visuals.gradientColors,
            height: 230,
            borderRadius: 11,
          ),
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
        // Wrap: con precios de 8 cifras y pantallas angostas, el precio
        // anterior y el descuento bajan de línea en vez de desbordarse.
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
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
              Text(
                formatPrice(product.oldPriceCents!),
                style: const TextStyle(
                  fontSize: 13,
                  color: NexusColors.textFaint,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              NexusDiscountBadge(label: '-${product.discountPercent}%'),
            ],
          ],
        ),
        const SizedBox(height: 18),
        _PurchasePanel(product: product),
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

/// Compra (HU-005): oferta de qué proveedor, cuántas unidades y agregar al
/// carrito. NEXUS es intermediario: cada proveedor vende y despacha su oferta
/// (RN-009). Sin stock, los botones quedan deshabilitados.
class _PurchasePanel extends ConsumerStatefulWidget {
  const _PurchasePanel({required this.product});

  final Product product;

  @override
  ConsumerState<_PurchasePanel> createState() => _PurchasePanelState();
}

class _PurchasePanelState extends ConsumerState<_PurchasePanel> {
  /// Tope por línea del carrito (API_CONTRATO, parte 2). El backend valida
  /// además contra el stock y responde cuántas quedan.
  static const _maxQuantity = 10;

  late String? _offerId =
      widget.product.bestOfferId ??
      widget.product.offers
          .where((offer) => offer.stockLevel != StockLevel.outOfStock)
          .firstOrNull
          ?.id;
  var _quantity = 1;
  var _adding = false;

  StockLevel get _stockLevel {
    for (final offer in widget.product.offers) {
      if (offer.id == _offerId) return offer.stockLevel;
    }
    return widget.product.stockLevel;
  }

  bool get _canBuy => _offerId != null && _stockLevel != StockLevel.outOfStock;

  Future<void> _add({required bool openCart}) async {
    final offerId = _offerId;
    if (offerId == null || _adding) return;
    setState(() => _adding = true);
    await addToCart(
      context,
      ref,
      offerId: offerId,
      quantity: _quantity,
      openCart: openCart,
    );
    if (mounted) setState(() => _adding = false);
  }

  @override
  Widget build(BuildContext context) {
    final offers = widget.product.offers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (offers.isNotEmpty) ...[
          NexusUnderlineTitle(
            offers.length == 1 ? 'VENDIDO POR' : 'ELIGE EL PROVEEDOR',
          ),
          const SizedBox(height: 4),
          NexusCard(
            child: Column(
              children: [
                for (var index = 0; index < offers.length; index++) ...[
                  if (index > 0)
                    const Divider(color: NexusColors.border, height: 1),
                  _OfferRow(
                    offer: offers[index],
                    selectable: offers.length > 1,
                    selected: offers[index].id == _offerId,
                    onSelect: () => setState(() {
                      _offerId = offers[index].id;
                      _quantity = 1;
                    }),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (!_canBuy)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              'Agotado: por ahora no se puede agregar al carrito.',
              style: TextStyle(fontSize: 11.5, color: NexusColors.pink),
            ),
          ),
        Row(
          children: [
            NexusQuantityStepper(
              value: _quantity,
              onDecrement: _canBuy && _quantity > 1
                  ? () => setState(() => _quantity--)
                  : null,
              onIncrement: _canBuy && _quantity < _maxQuantity
                  ? () => setState(() => _quantity++)
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: NexusPrimaryButton(
                label: 'COMPRAR AHORA',
                enabled: _canBuy && !_adding,
                onPressed: () => _add(openCart: true),
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
                enabled: _canBuy,
                loading: _adding,
                onPressed: () => _add(openCart: false),
                color: NexusColors.cyan,
                foregroundColor: NexusColors.onCyan,
                icon: Icons.shopping_cart,
                fullWidth: false,
                fontSize: 9,
                padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
                borderRadius: 8,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OfferRow extends StatelessWidget {
  const _OfferRow({
    required this.offer,
    required this.selectable,
    required this.selected,
    required this.onSelect,
  });

  final ProductOffer offer;
  final bool selectable;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final available = offer.stockLevel != StockLevel.outOfStock;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          if (selectable) ...[
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: !available
                  ? NexusColors.textFaint
                  : selected
                  ? NexusColors.cyan
                  : NexusColors.textDim,
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  offer.providerName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                NexusStatusDot(
                  ProductVisuals.stockLabel(offer.stockLevel),
                  color: ProductVisuals.stockColor(offer.stockLevel),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatPrice(offer.priceCents),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: NexusColors.cyan,
                ),
              ),
              if (offer.hasDiscount)
                Text(
                  formatPrice(offer.oldPriceCents!),
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: NexusColors.textFaint,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    if (!selectable) return row;
    return Semantics(
      selected: selected,
      enabled: available,
      button: true,
      child: InkWell(onTap: available ? onSelect : null, child: row),
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
      imageUrl: product.imageUrl,
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
