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
import '../../account/account_providers.dart';
import '../catalog_providers.dart';
import '../domain/product.dart';
import '../../cart/presentation/cart_actions.dart';
import 'product_visuals.dart';
import 'store_catalog_screen.dart';

/// Argumentos de `NexusRoutes.productDetail` desde una tarjeta del catálogo:
/// el producto y la oferta de la tienda de esa tarjeta. Las demás pantallas
/// envían solo el id del producto (`String`).
class ProductDetailArgs {
  const ProductDetailArgs(this.productId, {this.offerId});

  final String productId;
  final String? offerId;
}

class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({
    super.key,
    required this.productId,
    this.initialOfferId,
  });

  final String productId;

  /// Oferta seleccionada al abrir; si no, la mejor.
  final String? initialOfferId;

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
              : _ProductDetailContent(
                  product: product,
                  initialOfferId: initialOfferId,
                ),
        ),
      ],
    );
  }
}

/// Ficha del producto con la oferta seleccionada: el precio, el descuento y
/// el stock que se muestran son los de esa tienda.
class _ProductDetailContent extends ConsumerStatefulWidget {
  const _ProductDetailContent({required this.product, this.initialOfferId});

  final Product product;
  final String? initialOfferId;

  @override
  ConsumerState<_ProductDetailContent> createState() => _ProductDetailContentState();
}

class _ProductDetailContentState extends ConsumerState<_ProductDetailContent> {
  late String? _offerId = _initialOfferId();

  Product get product => widget.product;

  String? _initialOfferId() {
    final requested = widget.initialOfferId;
    if (requested != null && product.offers.any((offer) => offer.id == requested)) {
      return requested;
    }
    return product.bestOfferId ??
        product.offers
            .where((offer) => offer.stockLevel != StockLevel.outOfStock)
            .firstOrNull
            ?.id;
  }

  ProductOffer? get _selected =>
      product.offers.where((offer) => offer.id == _offerId).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final visuals = ProductVisuals.forCategory(product.category);
    final selected = _selected;
    final stockLevel = selected?.stockLevel ?? product.stockLevel;
    final priceCents = selected?.priceCents ?? product.priceCents;
    final oldPriceCents = selected == null ? product.oldPriceCents : selected.oldPriceCents;
    final hasDiscount = oldPriceCents != null && oldPriceCents > priceCents;
    final stockLabel = switch (stockLevel) {
      StockLevel.stable => 'EN STOCK',
      StockLevel.critical => 'CRÍTICO',
      StockLevel.outOfStock => ProductVisuals.stockLabel(stockLevel),
    };
    final stockColor = switch (stockLevel) {
      StockLevel.stable => NexusColors.green,
      StockLevel.critical => NexusColors.pink,
      StockLevel.outOfStock => ProductVisuals.stockColor(stockLevel),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Breadcrumb(
          categoryLabel: visuals.categoryLabel,
          productName: product.name,
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: product.imageUrl == null ? null : () => _showZoom(context, product.imageUrl!),
          child: Stack(
            children: [
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
              if (product.imageUrl != null)
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: NexusColors.bg.withValues(alpha: 0.7), shape: BoxShape.circle),
                    child: const Icon(Icons.zoom_in, size: 18, color: NexusColors.cyan),
                  ),
                ),
            ],
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
              formatPrice(priceCents),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: NexusColors.cyan,
              ),
            ),
            if (hasDiscount) ...[
              Text(
                formatPrice(oldPriceCents),
                style: const TextStyle(
                  fontSize: 13,
                  color: NexusColors.textFaint,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              NexusDiscountBadge(
                label: '-${((oldPriceCents - priceCents) * 100 / oldPriceCents).round()}%',
              ),
            ],
          ],
        ),
        if (selected != null) ...[
          const SizedBox(height: 14),
          _SellerTile(offer: selected, otherStores: product.offers.length - 1),
        ],
        const SizedBox(height: 18),
        _PurchasePanel(
          product: product,
          offerId: _offerId,
          stockLevel: stockLevel,
          onSelectOffer: (offerId) => setState(() => _offerId = offerId),
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

/// Compra (HU-005): comparar las ofertas de cada tienda, elegir una, cuántas
/// unidades y agregar al carrito. NEXUS es intermediario: cada tienda vende y
/// despacha su oferta (RN-009). Sin stock, los botones quedan deshabilitados.
/// Las cuentas que no compran (tiendas y administradores) solo comparan.
class _PurchasePanel extends ConsumerStatefulWidget {
  const _PurchasePanel({
    required this.product,
    required this.offerId,
    required this.stockLevel,
    required this.onSelectOffer,
  });

  final Product product;
  final String? offerId;
  final StockLevel stockLevel;
  final ValueChanged<String> onSelectOffer;

  @override
  ConsumerState<_PurchasePanel> createState() => _PurchasePanelState();
}

class _PurchasePanelState extends ConsumerState<_PurchasePanel> {
  /// Tope por línea del carrito (API_CONTRATO, parte 2). El backend valida
  /// además contra el stock y responde cuántas quedan.
  static const _maxQuantity = 10;

  var _quantity = 1;
  var _adding = false;

  String? get _offerId => widget.offerId;

  bool get _canBuy => _offerId != null && widget.stockLevel != StockLevel.outOfStock;

  @override
  void didUpdateWidget(covariant _PurchasePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.offerId != widget.offerId) _quantity = 1;
  }

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
      productName: widget.product.name,
    );
    if (mounted) setState(() => _adding = false);
  }

  @override
  Widget build(BuildContext context) {
    final offers = widget.product.offers;
    final accountCanBuy = ref.watch(canBuyProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Con una sola tienda, "Vendido por" ya la muestra arriba.
        if (offers.length > 1) ...[
          const NexusUnderlineTitle('COMPARAR TIENDAS'),
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
                    onSelect: () => widget.onSelectOffer(offers[index].id),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (!accountCanBuy)
          const Text(
            'Las cuentas de tienda y de administración no compran en NEXUS.',
            style: TextStyle(fontSize: 11.5, color: NexusColors.textDim),
          )
        else ..._buyControls(),
      ],
    );
  }

  List<Widget> _buyControls() {
    return [
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
    ];
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
          IconButton(
            tooltip: 'Ver la tienda ${offer.providerName}',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.storefront_outlined, size: 19, color: NexusColors.textDim),
            onPressed: () => openStore(context, offer),
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

/// Abre el catálogo de la tienda que vende [offer].
void openStore(BuildContext context, ProductOffer offer) => Navigator.of(context).pushNamed(
  NexusRoutes.store,
  arguments: StoreCatalogArgs(offer.providerId, offer.providerName),
);

/// Foto a pantalla completa: se amplía con dos dedos o doble toque.
void _showZoom(BuildContext context, String imageUrl) => showDialog<void>(
  context: context,
  barrierColor: Colors.black.withValues(alpha: 0.92),
  builder: (context) => Stack(
    children: [
      Positioned.fill(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Center(child: Image.network(imageUrl, fit: BoxFit.contain)),
        ),
      ),
      Positioned(
        top: 40,
        right: 16,
        child: IconButton(
          tooltip: 'Cerrar',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close, color: Colors.white, size: 28),
        ),
      ),
    ],
  ),
);

/// "Vendido por": la tienda de la oferta seleccionada. Abre su catálogo.
class _SellerTile extends StatelessWidget {
  const _SellerTile({required this.offer, required this.otherStores});

  final ProductOffer offer;
  final int otherStores;

  @override
  Widget build(BuildContext context) {
    final name = offer.providerName;
    return Material(
      color: NexusColors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => openStore(context, offer),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: NexusColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: NexusColors.cyan.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: NexusColors.cyan.withValues(alpha: 0.5)),
                ),
                alignment: Alignment.center,
                child: Text(
                  name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: NexusColors.cyan),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('VENDIDO POR', style: NexusText.sectionLabel),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, size: 14, color: NexusColors.cyan),
                      ],
                    ),
                    if (otherStores > 0)
                      Text(
                        otherStores == 1 ? 'Otra tienda también lo vende' : 'Otras $otherStores tiendas también lo venden',
                        style: const TextStyle(fontSize: 10.5, color: NexusColors.textDim),
                      ),
                  ],
                ),
              ),
              const Text(
                'Ver tienda',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: NexusColors.cyan),
              ),
              const Icon(Icons.chevron_right, size: 18, color: NexusColors.cyan),
            ],
          ),
        ),
      ),
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
