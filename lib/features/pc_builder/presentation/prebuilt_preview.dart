import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/format_price.dart';
import '../../../routes.dart';
import '../../../theme/nexus_theme.dart';
import '../../../widgets/nexus_error_state.dart';
import '../../../widgets/nexus_loading.dart';
import '../../../widgets/nexus_widgets.dart';
import '../../cart/presentation/cart_actions.dart';
import '../../catalog/domain/product.dart';
import '../domain/build_scene.dart';
import '../domain/pc_builder_models.dart';
import '../pc_builder_providers.dart';
import 'viewer/pc_viewer.dart';

/// "Visualizar en 3D" de un computador armado (RF-090): sus componentes en
/// las secciones del PC Builder y en la vista 3D. Es solo para ver; el armado
/// se compra completo y la configuración del cliente no se toca.
class PrebuiltPreviewView extends ConsumerWidget {
  const PrebuiltPreviewView({
    super.key,
    required this.productId,
    required this.slots,
  });

  final String productId;
  final List<BuilderSlot> slots;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prebuilt = ref.watch(prebuiltSceneProvider(productId));
    final close = ref.read(prebuiltPreviewProvider.notifier).close;

    if (prebuilt.value case final prebuilt?) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Banner(product: prebuilt.product),
          const SizedBox(height: 16),
          if (prebuilt.hasComponents)
            const PcViewer()
          else
            const Text(
              'Este armado todavía no tiene sus componentes registrados, así '
              'que no se puede ver en 3D.',
              style: NexusText.body,
            ),
          const SizedBox(height: 16),
          const NexusBracketTitle('COMPONENTES DEL ARMADO'),
          const SizedBox(height: 12),
          for (final slot in slots)
            _ComponentCard(
              key: ValueKey(slot.category),
              slot: slot,
              component: prebuilt.scene.partFor(slot.category),
            ),
          const SizedBox(height: 8),
          _Actions(product: prebuilt.product, onClose: close),
          const SizedBox(height: 20),
        ],
      );
    }
    if (prebuilt.hasError) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NexusErrorState(
            message: 'No se pudo cargar el computador armado.',
            onRetry: () => ref.invalidate(prebuiltSceneProvider(productId)),
          ),
          NexusOutlineButton(label: 'VOLVER A MI CONFIGURACIÓN', onPressed: close),
        ],
      );
    }
    return const NexusLoading();
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NexusColors.cyan.withValues(alpha: 0.08),
        border: Border.all(color: NexusColors.cyan.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.view_in_ar, color: NexusColors.cyan),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('COMPUTADOR ARMADO', style: NexusText.sectionLabel),
                const SizedBox(height: 4),
                Text(
                  product.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: NexusColors.text),
                ),
                const SizedBox(height: 2),
                Text(
                  formatPrice(product.priceCents),
                  style: const TextStyle(fontWeight: FontWeight.w800, color: NexusColors.cyan),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Estás viendo sus componentes. Se compra completo; tu '
                  'configuración del PC Builder no cambió.',
                  style: TextStyle(fontSize: 12, color: NexusColors.textDim),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComponentCard extends StatelessWidget {
  const _ComponentCard({super.key, required this.slot, required this.component});

  final BuilderSlot slot;
  final ScenePart? component;

  @override
  Widget build(BuildContext context) {
    final component = this.component;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: NexusColors.card,
          border: Border.all(color: NexusColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    slot.label.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: NexusColors.textDim,
                    ),
                  ),
                ),
                NexusTag(
                  component == null ? 'NO INCLUYE' : 'INCLUIDO',
                  color: component == null ? NexusColors.textDim : NexusColors.green,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              component?.productName ??
                  (slot.category == ProductCategory.gpu
                      ? 'Usa los gráficos integrados del procesador.'
                      : 'Este armado no trae esta pieza.'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: component == null ? FontWeight.normal : FontWeight.bold,
                color: component == null ? NexusColors.textFaint : NexusColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.product, required this.onClose});

  final Product product;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offerId = product.bestOfferId;
    final available = offerId != null && product.stockLevel != StockLevel.outOfStock;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NexusPrimaryButton(
          label: available ? 'AGREGAR EL ARMADO AL CARRITO' : 'ARMADO AGOTADO',
          icon: Icons.add_shopping_cart,
          enabled: available,
          onPressed: available ? () => addToCart(context, ref, offerId: offerId) : null,
        ),
        const SizedBox(height: 8),
        NexusOutlineButton(
          label: 'VER DETALLE DEL ARMADO',
          onPressed: () => Navigator.of(context)
              .pushNamed(NexusRoutes.productDetail, arguments: product.id),
        ),
        const SizedBox(height: 8),
        NexusOutlineButton(
          label: 'VOLVER A MI CONFIGURACIÓN',
          color: NexusColors.cyan,
          onPressed: onClose,
        ),
      ],
    );
  }
}
