import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/utils/format_price.dart';
import '../../../routes.dart';
import '../../../screens/shell/main_shell.dart';
import '../../../theme/nexus_theme.dart';
import '../../../widgets/nexus_product_image.dart';
import '../../../widgets/nexus_top_bar.dart';
import '../../../widgets/nexus_widgets.dart';
import '../../cart/presentation/cart_actions.dart';
import '../../catalog/domain/product.dart';
import '../../catalog/presentation/catalog_screen.dart';
import '../../catalog/presentation/product_visuals.dart';
import '../../pc_builder/pc_builder_providers.dart';
import '../../pc_builder/presentation/pc_builder_screen.dart';
import '../assistant_providers.dart';
import '../domain/assistant_models.dart';
import 'voice_composer.dart';

/// Asistente de recomendación (HU-006): el cliente describe lo que necesita,
/// por texto o por voz, y recibe productos del catálogo o una configuración
/// de piezas que puede abrir en el PC Builder. Nunca compra por él (RF-042).
class AssistantScreen extends StatelessWidget {
  const AssistantScreen({super.key});

  static const suggestions = [
    'Necesito un computador de oficina para trabajar y editar videos',
    'Quiero jugar en 4K y tengo unos 9 millones',
    'Ármame un PC por piezas para diseño gráfico',
  ];

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: NexusColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NexusTopBar(title: 'ASISTENTE'),
            _Notice(),
            Expanded(child: _Conversation()),
            VoiceComposer(),
          ],
        ),
      ),
    );
  }
}

/// Aviso de contenido generado (RNF-025) y botón de conversación nueva.
class _Notice extends ConsumerWidget {
  const _Notice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasConversation = ref.watch(
      assistantControllerProvider.select((state) => !state.isEmpty),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, size: 14, color: NexusColors.textFaint),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'Respuestas generadas con IA a partir del catálogo. Revisa antes de comprar.',
              style: TextStyle(fontSize: 11, color: NexusColors.textFaint),
            ),
          ),
          if (hasConversation)
            TextButton(
              onPressed: () => ref.read(assistantControllerProvider.notifier).restart(),
              child: const Text('Nueva'),
            ),
        ],
      ),
    );
  }
}

class _Conversation extends ConsumerWidget {
  const _Conversation();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(assistantControllerProvider.select((state) => state.entries));
    final sending = ref.watch(assistantControllerProvider.select((state) => state.sending));

    if (entries.isEmpty && !sending) return const _Welcome();

    final extra = sending ? 1 : 0;
    // Lista invertida: lo más reciente queda abajo, junto al campo de texto.
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      itemCount: entries.length + extra,
      itemBuilder: (context, index) {
        if (sending && index == 0) return const _Thinking();
        final entry = entries[entries.length - 1 - (index - extra)];
        final isLast = index == extra;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: switch (entry) {
            UserEntry(:final text) => _UserBubble(text),
            ReplyEntry(:final reply) => _ReplyView(reply),
            FailureEntry(:final failure) => _FailureView(failure, canRetry: isLast),
          },
        );
      },
    );
  }
}

class _Welcome extends ConsumerWidget {
  const _Welcome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 12),
        const Icon(Icons.auto_awesome, size: 40, color: NexusColors.cyan),
        const SizedBox(height: 12),
        const Text(
          '¿Qué computador necesitas?',
          textAlign: TextAlign.center,
          style: NexusText.display,
        ),
        const SizedBox(height: 8),
        const Text(
          'Cuéntame para qué lo vas a usar y cuánto quieres gastar. Puedes '
          'escribir o dictar con el micrófono. Te recomiendo productos del '
          'catálogo o te armo una configuración que puedes ver en 3D.',
          textAlign: TextAlign.center,
          style: NexusText.body,
        ),
        const SizedBox(height: 20),
        for (final suggestion in AssistantScreen.suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: NexusOutlineButton(
              label: suggestion,
              bold: false,
              borderColor: NexusColors.border,
              onPressed: () =>
                  ref.read(assistantControllerProvider.notifier).send(suggestion),
            ),
          ),
      ],
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: NexusColors.cyan.withValues(alpha: 0.14),
            border: Border.all(color: NexusColors.cyan.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(text, style: NexusText.body.copyWith(color: NexusColors.text)),
        ),
      ),
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  const _AssistantBubble(this.text, {this.color = NexusColors.border});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NexusColors.card,
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('NEXUS IA', style: NexusText.sectionLabel),
          const SizedBox(height: 6),
          Text(text, style: NexusText.body.copyWith(color: NexusColors.text)),
        ],
      ),
    );
  }
}

class _ReplyView extends StatelessWidget {
  const _ReplyView(this.reply);

  final AssistantReply reply;

  @override
  Widget build(BuildContext context) {
    final reply = this.reply;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AssistantBubble(reply.message),
        if (reply case AssistantRecommendation(:final products, :final build)) ...[
          for (final item in products) ...[
            const SizedBox(height: 10),
            _RecommendedProductCard(item),
          ],
          if (build != null) ...[
            const SizedBox(height: 10),
            _BuildProposalCard(build),
          ],
        ],
        if (reply is AssistantNoMatch) ...[
          const SizedBox(height: 10),
          const _Shortcuts(),
        ],
      ],
    );
  }
}

class _RecommendedProductCard extends ConsumerWidget {
  const _RecommendedProductCard(this.item);

  final RecommendedProduct item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = item.product;
    final visuals = ProductVisuals.forCategory(product.category);
    final offerId = product.bestOfferId;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NexusColors.cardAlt,
        border: Border.all(color: NexusColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 64,
                child: NexusProductImage(
                  imageUrl: product.imageUrl,
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
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: NexusColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${product.brand} · ${visuals.categoryLabel}',
                      style: const TextStyle(fontSize: 12, color: NexusColors.textDim),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          formatPrice(product.priceCents),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: NexusColors.cyan,
                          ),
                        ),
                        if (product.stockLevel == StockLevel.critical)
                          const NexusTag('POCAS UNIDADES', color: NexusColors.pink),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(item.reason, style: NexusText.body),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: NexusOutlineButton(
                  label: 'VER DETALLE',
                  compact: true,
                  onPressed: () => Navigator.of(context)
                      .pushNamed(NexusRoutes.productDetail, arguments: product.id),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NexusPrimaryButton(
                  label: 'AGREGAR',
                  icon: Icons.add_shopping_cart,
                  enabled: offerId != null,
                  onPressed: offerId == null
                      ? null
                      : () => addToCart(context, ref, offerId: offerId),
                ),
              ),
            ],
          ),
          if (product.category == ProductCategory.prebuiltPc) ...[
            const SizedBox(height: 8),
            NexusOutlineButton(
              label: 'VISUALIZAR EN 3D',
              color: NexusColors.cyan,
              borderColor: NexusColors.cyan,
              onPressed: () => _visualize(context, ref, product.id),
            ),
          ],
        ],
      ),
    );
  }

  /// Abre el armado en el PC Builder: sus componentes por sección y en 3D.
  void _visualize(BuildContext context, WidgetRef ref, String productId) {
    ref.read(prebuiltPreviewProvider.notifier).show(productId);
    final shell = MainShellScope.maybeOf(context);
    if (shell != null) {
      shell.selectTab(NexusTab.pcBuilder);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const PcBuilderScreen()),
      );
    }
  }
}

/// Configuración de piezas propuesta (RF-040). Ya está validada; se abre en
/// el PC Builder, donde se ve en 3D y se puede ajustar o llevar al carrito.
class _BuildProposalCard extends ConsumerStatefulWidget {
  const _BuildProposalCard(this.build);

  final ProposedBuild build;

  @override
  ConsumerState<_BuildProposalCard> createState() => _BuildProposalCardState();
}

class _BuildProposalCardState extends ConsumerState<_BuildProposalCard> {
  bool _opening = false;

  Future<void> _openInBuilder() async {
    setState(() => _opening = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final shell = MainShellScope.maybeOf(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(pcBuilderControllerProvider.notifier).loadBuild(widget.build.offerIds);
      // Si había un armado en vista, se cierra para mostrar esta configuración.
      ref.read(prebuiltPreviewProvider.notifier).close();
      if (shell != null) {
        shell.selectTab(NexusTab.pcBuilder);
      } else {
        await navigator.push(
          MaterialPageRoute<void>(builder: (_) => const PcBuilderScreen()),
        );
      }
    } on AppFailure catch (failure) {
      messenger?.showSnackBar(SnackBar(content: Text(failure.userMessage)));
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final validation = widget.build.validation;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NexusColors.cardAlt,
        border: Border.all(color: NexusColors.green.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text('CONFIGURACIÓN POR PIEZAS', style: NexusText.sectionLabel),
              ),
              NexusTag('COMPATIBLE', color: NexusColors.green),
            ],
          ),
          if (widget.build.reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(widget.build.reason, style: NexusText.body),
          ],
          const SizedBox(height: 10),
          for (final part in validation.parts)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${ProductVisuals.partLabel(part.category).toUpperCase()}\n',
                            style: const TextStyle(fontSize: 10, color: NexusColors.textFaint),
                          ),
                          TextSpan(
                            text: part.productName,
                            style: const TextStyle(fontSize: 13, color: NexusColors.text),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatPrice(part.priceCents),
                    style: const TextStyle(fontSize: 13, color: NexusColors.textDim),
                  ),
                ],
              ),
            ),
          const Divider(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text('TOTAL', style: NexusText.sectionLabel),
              ),
              Text(
                formatPrice(validation.totalCents),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: NexusColors.cyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          NexusPrimaryButton(
            label: 'VER EN EL PC BUILDER (3D)',
            icon: Icons.view_in_ar,
            loading: _opening,
            onPressed: _openInBuilder,
          ),
        ],
      ),
    );
  }
}

/// Otras formas de comprar cuando el asistente no puede ayudar.
class _Shortcuts extends StatelessWidget {
  const _Shortcuts();

  @override
  Widget build(BuildContext context) {
    void open(NexusTab tab, Widget fallback) {
      final shell = MainShellScope.maybeOf(context);
      if (shell != null) {
        shell.selectTab(tab);
      } else {
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => fallback));
      }
    }

    return Row(
      children: [
        Expanded(
          child: NexusOutlineButton(
            label: 'IR AL CATÁLOGO',
            compact: true,
            onPressed: () => open(NexusTab.catalog, const CatalogScreen()),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: NexusOutlineButton(
            label: 'PC BUILDER',
            compact: true,
            onPressed: () => open(NexusTab.pcBuilder, const PcBuilderScreen()),
          ),
        ),
      ],
    );
  }
}

class _FailureView extends ConsumerWidget {
  const _FailureView(this.failure, {required this.canRetry});

  final AppFailure failure;
  final bool canRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AssistantBubble(failure.userMessage, color: NexusColors.pink),
        if (canRetry) ...[
          const SizedBox(height: 8),
          NexusOutlineButton(
            label: 'REINTENTAR',
            compact: true,
            color: NexusColors.cyan,
            onPressed: () => ref.read(assistantControllerProvider.notifier).retry(),
          ),
        ],
        if (failure is AssistantUnavailableFailure) ...[
          const SizedBox(height: 8),
          const _Shortcuts(),
        ],
      ],
    );
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: NexusColors.cyan),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Buscando en el catálogo...',
              style: TextStyle(color: NexusColors.textDim),
            ),
          ),
        ],
      ),
    );
  }
}
