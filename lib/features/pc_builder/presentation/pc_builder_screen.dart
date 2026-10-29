import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/format_price.dart';
import '../../../routes.dart';
import '../../../theme/nexus_theme.dart';
import '../../../widgets/nexus_error_state.dart';
import '../../../widgets/nexus_loading.dart';
import '../../../widgets/nexus_page.dart';
import '../../../widgets/nexus_product_image.dart';
import '../../../widgets/nexus_widgets.dart';
import '../../cart/presentation/cart_actions.dart';
import '../../catalog/presentation/product_detail_screen.dart';
import '../../catalog/presentation/product_visuals.dart';
import '../domain/pc_builder_models.dart';
import '../pc_builder_providers.dart';
import 'part_picker_screen.dart';
import 'viewer/pc_viewer.dart';

/// PC Builder (HU-008): una pieza por ranura, validada por el motor de reglas
/// del backend. Explica cada incompatibilidad y qué pieza falta, y permite
/// llevar la configuración completa al carrito (RF-051).
class PcBuilderScreen extends ConsumerWidget {
  const PcBuilderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slots = ref.watch(builderSlotsProvider);
    final builder = ref.watch(pcBuilderControllerProvider);

    final Widget content;
    if (slots.value case final slots? when builder.value != null) {
      content = _BuilderContent(slots: slots, state: builder.value!);
    } else if (slots.hasError || builder.hasError) {
      content = NexusErrorState(
        message: 'No se pudo cargar el armador.\n'
            '${cartErrorMessage(slots.error ?? builder.error!)}',
        onRetry: () {
          ref.invalidate(builderSlotsProvider);
          ref.invalidate(pcBuilderControllerProvider);
        },
      );
    } else {
      content = const NexusLoading();
    }

    return NexusPage(
      title: 'PC BUILDER',
      children: [
        const Text(
          'Elige una pieza de cada tipo. Revisamos la compatibilidad con '
          'reglas técnicas y te explicamos cualquier problema.',
          style: NexusText.body,
        ),
        const SizedBox(height: 16),
        content,
      ],
    );
  }
}

class _BuilderContent extends ConsumerWidget {
  const _BuilderContent({required this.slots, required this.state});

  final List<BuilderSlot> slots;
  final BuilderState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final validation = state.validation;
    final generalIssues = [
      for (final issue in validation.issues)
        if (issue.offerIds.isEmpty) issue,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatusBanner(slots: slots, state: state),
        for (final issue in generalIssues) _IssueLine(issue: issue),
        const SizedBox(height: 16),
        const PcViewer(),
        const SizedBox(height: 16),
        const NexusBracketTitle('SELECCIÓN DE COMPONENTES'),
        const SizedBox(height: 12),
        for (final slot in slots)
          _SlotCard(
            key: ValueKey(slot.category),
            slot: slot,
            part: validation.partFor(slot.category),
            validation: validation,
          ),
        const SizedBox(height: 14),
        const NexusBracketTitle('RESUMEN'),
        const SizedBox(height: 12),
        _Summary(state: state),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.slots, required this.state});

  final List<BuilderSlot> slots;
  final BuilderState state;

  @override
  Widget build(BuildContext context) {
    final validation = state.validation;
    final requiredCount = slots.where((slot) => slot.required).length;
    final filled = requiredCount - validation.missingSlots.length;
    final errorCount = validation.errors.length;

    final (IconData icon, Color color, String text) = switch (validation) {
      _ when state.isEmpty => (
        Icons.memory,
        NexusColors.cyan,
        'Empieza por el procesador: el resto de piezas depende de él.',
      ),
      _ when errorCount > 0 => (
        Icons.error_outline,
        NexusColors.pink,
        errorCount == 1
            ? 'Hay 1 incompatibilidad. Revisa las piezas marcadas.'
            : 'Hay $errorCount incompatibilidades. Revisa las piezas marcadas.',
      ),
      _ when validation.missingSlots.isNotEmpty => (
        Icons.playlist_add,
        NexusColors.cyan,
        'Falta: ${validation.missingSlots.map((s) => s.label).join(', ')}.',
      ),
      _ when !validation.purchasable => (
        Icons.inventory_2_outlined,
        NexusColors.pink,
        'La configuración es compatible, pero hay piezas sin stock.',
      ),
      _ => (
        Icons.check_circle_outline,
        NexusColors.green,
        'Configuración compatible y completa.',
      ),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: const TextStyle(fontSize: 12.5, color: NexusColors.text),
                ),
                const SizedBox(height: 4),
                Text(
                  '$filled de $requiredCount piezas obligatorias',
                  style: const TextStyle(fontSize: 10.5, color: NexusColors.textDim),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IssueLine extends StatelessWidget {
  const _IssueLine({required this.issue});

  final BuildIssue issue;

  @override
  Widget build(BuildContext context) {
    final color = issue.isError ? NexusColors.pink : NexusColors.textDim;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            issue.isError ? Icons.cancel_outlined : Icons.info_outline,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              issue.message,
              style: TextStyle(
                fontSize: 11.5,
                color: issue.isError ? NexusColors.text : NexusColors.textDim,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotCard extends ConsumerWidget {
  const _SlotCard({
    super.key,
    required this.slot,
    required this.part,
    required this.validation,
  });

  final BuilderSlot slot;
  final BuildPart? part;
  final BuildValidation validation;

  void _openPicker(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PartPickerScreen(slot: slot)),
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(pcBuilderControllerProvider.notifier).remove(slot.category);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(cartErrorMessage(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final part = this.part;
    final visuals = ProductVisuals.forCategory(slot.category);
    final issues = part == null ? const <BuildIssue>[] : validation.issuesFor(part.offerId);
    final hasErrors = issues.any((issue) => issue.isError);
    final missing = validation.missingSlots.any((s) => s.category == slot.category);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: NexusColors.card,
          border: Border.all(
            color: hasErrors || (part != null && !part.isAvailable)
                ? NexusColors.pink
                : NexusColors.border,
          ),
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
                if (part == null)
                  NexusTag(
                    slot.required ? 'OBLIGATORIA' : 'OPCIONAL',
                    color: missing ? NexusColors.pink : NexusColors.textDim,
                  )
                else if (!part.isAvailable)
                  const NexusTag('SIN STOCK', color: NexusColors.pink),
              ],
            ),
            const SizedBox(height: 8),
            if (part == null)
              NexusOutlineButton(
                label: 'Elegir ${slot.label.toLowerCase()}',
                compact: true,
                onPressed: () => _openPicker(context),
              )
            else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 52,
                    child: NexusProductImage(
                      imageUrl: part.imageUrl,
                      icon: visuals.icon,
                      gradientColors: visuals.gradientColors,
                      height: 52,
                      borderRadius: 8,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          part.productName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${part.brand} · ${part.providerName}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: NexusColors.textFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatPrice(part.priceCents),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: NexusColors.cyan,
                    ),
                  ),
                ],
              ),
              for (final issue in issues) _IssueLine(issue: issue),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                children: [
                  // La ficha completa, con la oferta de la tienda elegida.
                  TextButton(
                    onPressed: () => Navigator.of(context).pushNamed(
                      NexusRoutes.productDetail,
                      arguments: ProductDetailArgs(part.productId, offerId: part.offerId),
                    ),
                    child: const Text('Ver detalles'),
                  ),
                  TextButton(
                    onPressed: () => _openPicker(context),
                    child: Text(
                      hasErrors || !part.isAvailable ? 'Ver alternativas' : 'Cambiar',
                    ),
                  ),
                  TextButton(
                    onPressed: () => _remove(context, ref),
                    style: TextButton.styleFrom(foregroundColor: NexusColors.pink),
                    child: const Text('Quitar'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Summary extends ConsumerStatefulWidget {
  const _Summary({required this.state});

  final BuilderState state;

  @override
  ConsumerState<_Summary> createState() => _SummaryState();
}

class _SummaryState extends ConsumerState<_Summary> {
  var _adding = false;

  /// Agrega cada pieza al carrito (RF-051). Si alguna falla, informa cuál.
  Future<void> _addToCart() async {
    setState(() => _adding = true);
    await addPartsToCart(context, ref, [
      for (final part in widget.state.validation.parts) (offerId: part.offerId, name: part.productName),
    ]);
    if (mounted) setState(() => _adding = false);
  }

  Future<void> _clear() async {
    try {
      await ref.read(pcBuilderControllerProvider.notifier).clear();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(cartErrorMessage(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final validation = widget.state.validation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NexusCard(
          child: Column(
            children: [
              const SizedBox(height: 8),
              for (final part in validation.parts)
                NexusSpecRow(
                  ProductVisuals.chipLabel(part.category),
                  formatPrice(part.priceCents),
                ),
              if (validation.parts.isNotEmpty)
                const Divider(color: NexusColors.border, height: 20),
              NexusSpecRow(
                'Total',
                formatPrice(validation.totalCents),
                valueColor: NexusColors.cyan,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        NexusPrimaryButton(
          label: 'AGREGAR TODO AL CARRITO',
          icon: Icons.shopping_cart,
          enabled: validation.purchasable,
          loading: _adding,
          onPressed: _addToCart,
        ),
        if (!validation.purchasable && !widget.state.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Completa una configuración compatible y con stock para agregarla.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.5, color: NexusColors.textDim),
            ),
          ),
        if (!widget.state.isEmpty) ...[
          const SizedBox(height: 10),
          NexusOutlineButton(
            label: 'Empezar de nuevo',
            color: NexusColors.pink,
            onPressed: _clear,
          ),
        ],
      ],
    );
  }
}
