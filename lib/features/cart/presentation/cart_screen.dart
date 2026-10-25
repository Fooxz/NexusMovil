import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/format_price.dart';
import '../../../routes.dart';
import '../../../theme/nexus_theme.dart';
import '../../../widgets/nexus_empty_state.dart';
import '../../../widgets/nexus_error_state.dart';
import '../../../widgets/nexus_loading.dart';
import '../../../widgets/nexus_page.dart';
import '../../../widgets/nexus_product_image.dart';
import '../../../widgets/nexus_quantity_stepper.dart';
import '../../../widgets/nexus_widgets.dart';
import '../../auth/auth_providers.dart';
import '../../auth/presentation/auth_guard.dart';
import '../../catalog/presentation/product_visuals.dart';
import '../cart_providers.dart';
import '../domain/cart_models.dart';
import 'cart_actions.dart';

/// Carrito (HU-009): líneas agrupadas por proveedor, cantidades limitadas a
/// lo disponible y resumen. Confirmar exige sesión (RN-027).
class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider);

    return NexusPage(
      title: 'CARRITO DE COMPRA',
      showBack: true,
      showCart: false,
      children: [
        // Al recargar se sigue mostrando el carrito anterior, sin parpadeo.
        if (cart.value case final state?)
          state.isEmpty ? const _EmptyCart() : _CartContent(state: state)
        else if (cart.hasError)
          NexusErrorState(
            message: 'No se pudo cargar tu carrito.\n'
                '${cartErrorMessage(cart.error!)}',
            onRetry: () => ref.invalidate(cartControllerProvider),
          )
        else
          const NexusLoading(),
      ],
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return NexusEmptyState(
      message: 'Tu carrito está vacío.',
      actionLabel: 'Seguir comprando',
      onAction: () => Navigator.of(context).maybePop(),
    );
  }
}

class _CartContent extends ConsumerWidget {
  const _CartContent({required this.state});

  final CartState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(currentUserProvider.select((u) => u != null));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!signedIn)
          const _Notice(
            icon: Icons.info_outline,
            text: 'Inicia sesión para guardar tu carrito y comprar.',
          ),
        if (state.groups.length > 1)
          _Notice(
            icon: Icons.local_shipping_outlined,
            text: 'Tu pedido llegará en ${state.groups.length} envíos, '
                'uno por proveedor.',
          ),
        for (final group in state.groups) _ProviderGroup(group: group),
        const SizedBox(height: 6),
        _Summary(state: state),
        const SizedBox(height: 18),
        _ConfirmOrderButton(enabled: state.canCheckout),
        const SizedBox(height: 10),
        const _ClearCartButton(),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? NexusColors.cyan;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        border: Border.all(color: accent.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 11.5, color: NexusColors.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderGroup extends StatelessWidget {
  const _ProviderGroup({required this.group});

  final CartProviderGroup group;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'VENDIDO Y DESPACHADO POR ${group.providerName.toUpperCase()}',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.4,
                color: NexusColors.textDim,
              ),
            ),
          ),
          for (final item in group.items)
            _CartLine(key: ValueKey(item.offerId), item: item),
        ],
      ),
    );
  }
}

class _CartLine extends ConsumerWidget {
  const _CartLine({super.key, required this.item});

  final CartItem item;

  Future<void> _run(
    BuildContext context,
    Future<void> Function(CartController) action,
  ) async {
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      await action(container.read(cartControllerProvider.notifier));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(cartErrorMessage(error))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visuals = ProductVisuals.forCategory(item.category);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NexusCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 64,
                    child: NexusProductImage(
                      imageUrl: item.imageUrl,
                      icon: visuals.icon,
                      gradientColors: visuals.gradientColors,
                      height: 64,
                      borderRadius: 8,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.brand} / ${visuals.shortCategoryLabel}',
                          style: const TextStyle(
                            fontSize: 9,
                            color: NexusColors.textFaint,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.productName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${formatPrice(item.unitPriceCents)} c/u',
                          style: const TextStyle(
                            fontSize: 11,
                            color: NexusColors.textDim,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Quitar del carrito',
                    onPressed: () => _run(
                      context,
                      (controller) => controller.remove(item.offerId),
                    ),
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: NexusColors.textDim,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (!item.isAvailable)
                const _Notice(
                  icon: Icons.block,
                  color: NexusColors.pink,
                  text: 'Ya no está disponible y no se incluirá en tu pedido.',
                )
              else if (item.exceedsStock)
                _StockAdjustment(item: item, onAdjust: _run),
              Row(
                children: [
                  if (item.isAvailable)
                    NexusQuantityStepper(
                      value: item.quantity,
                      compact: true,
                      onDecrement: item.canDecrease
                          ? () => _run(
                              context,
                              (controller) => controller.setQuantity(
                                item.offerId,
                                item.quantity - 1,
                              ),
                            )
                          : null,
                      onIncrement: item.canIncrease
                          ? () => _run(
                              context,
                              (controller) => controller.setQuantity(
                                item.offerId,
                                item.quantity + 1,
                              ),
                            )
                          : null,
                    ),
                  const Spacer(),
                  Text(
                    item.isPurchasable
                        ? formatPrice(item.subtotalCents)
                        : 'No incluido',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: item.isPurchasable
                          ? NexusColors.cyan
                          : NexusColors.textFaint,
                    ),
                  ),
                ],
              ),
              if (item.isAvailable && !item.canIncrease && !item.exceedsStock)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    item.maxQuantity == 1
                        ? 'Puedes llevar 1 unidad de este producto.'
                        : 'Puedes llevar hasta ${item.maxQuantity} unidades.',
                    style: const TextStyle(fontSize: 10.5, color: NexusColors.textDim),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StockAdjustment extends StatelessWidget {
  const _StockAdjustment({required this.item, required this.onAdjust});

  final CartItem item;
  final Future<void> Function(
    BuildContext,
    Future<void> Function(CartController),
  )
  onAdjust;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: NexusColors.pink.withValues(alpha: 0.08),
        border: Border.all(color: NexusColors.pink.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.maxQuantity == 1
                  ? 'Solo queda 1 unidad.'
                  : 'Solo quedan ${item.maxQuantity} unidades.',
              style: const TextStyle(fontSize: 11.5, color: NexusColors.text),
            ),
          ),
          TextButton(
            onPressed: () => onAdjust(
              context,
              (controller) =>
                  controller.setQuantity(item.offerId, item.maxQuantity),
            ),
            child: Text('Ajustar a ${item.maxQuantity}'),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.state});

  final CartState state;

  @override
  Widget build(BuildContext context) {
    return NexusCard(
      child: Column(
        children: [
          const SizedBox(height: 8),
          NexusSpecRow('Artículos', '${state.purchasableUnits}'),
          NexusSpecRow('Subtotal', formatPrice(state.subtotalCents)),
          const NexusSpecRow(
            'Envío',
            'Sin costo adicional',
            valueColor: NexusColors.textDim,
          ),
          const Divider(color: NexusColors.border, height: 20),
          NexusSpecRow(
            'Total',
            formatPrice(state.subtotalCents),
            valueColor: NexusColors.cyan,
          ),
          if (state.hasIssues)
            const Padding(
              padding: EdgeInsets.only(top: 8, bottom: 4),
              child: Text(
                'Revisa los productos marcados antes de confirmar.',
                style: TextStyle(fontSize: 11, color: NexusColors.pink),
              ),
            ),
        ],
      ),
    );
  }
}

/// Solo un cliente con sesión confirma una compra (RN-027): con sesión abre
/// el checkout (fase 8).
class _ConfirmOrderButton extends ConsumerWidget {
  const _ConfirmOrderButton({required this.enabled});

  final bool enabled;

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final signedIn = await ensureSignedIn(
      context,
      ref,
      reason: 'para confirmar tu pedido',
    );
    if (!signedIn || !context.mounted) return;
    await Navigator.of(context).pushNamed(NexusRoutes.checkout);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NexusPrimaryButton(
      label: 'Confirmar pedido',
      enabled: enabled,
      onPressed: () => _confirm(context, ref),
    );
  }
}

class _ClearCartButton extends ConsumerWidget {
  const _ClearCartButton();

  Future<void> _clear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vaciar carrito'),
        content: const Text('¿Quitar todos los productos del carrito?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Vaciar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(cartControllerProvider.notifier).clear();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(cartErrorMessage(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NexusOutlineButton(
      label: 'Vaciar carrito',
      color: NexusColors.pink,
      onPressed: () => _clear(context, ref),
    );
  }
}
