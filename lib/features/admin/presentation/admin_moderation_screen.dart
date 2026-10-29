import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/format_price.dart';
import '../../../theme/nexus_theme.dart';
import '../../../widgets/nexus_empty_state.dart';
import '../../../widgets/nexus_error_state.dart';
import '../../../widgets/nexus_loading.dart';
import '../../../widgets/nexus_page.dart';
import '../../../widgets/nexus_widgets.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../../catalog/presentation/product_visuals.dart';
import '../../provider_portal/domain/portal_models.dart';
import '../admin_console_providers.dart';
import '../domain/admin_console_models.dart';
import 'admin_offer_screen.dart';
import 'admin_widgets.dart';

/// Moderación posterior del catálogo: las tiendas publican sin aprobación y
/// el administrador revisa lo publicado. Primero lo que pide revisión y lo
/// que tiene más alertas de calidad.
class AdminModerationScreen extends ConsumerStatefulWidget {
  const AdminModerationScreen({super.key});

  @override
  ConsumerState<AdminModerationScreen> createState() => _AdminModerationScreenState();
}

class _AdminModerationScreenState extends ConsumerState<AdminModerationScreen> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => ref.read(adminOffersQueryProvider.notifier).setSearch(text),
    );
  }

  Future<void> _loadMore() async {
    try {
      await ref.read(adminOffersProvider.notifier).loadMore();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AuthErrorBanner.messageFor(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(adminOffersQueryProvider);
    final offers = ref.watch(adminOffersProvider);
    final counts = offers.value?.page.counts ?? const <String, int>{};
    String count(String key) => counts.containsKey(key) ? ' (${counts[key]})' : '';
    final notifier = ref.read(adminOffersQueryProvider.notifier);

    return NexusPage(
      title: 'MODERACIÓN',
      showCart: false,
      children: [
        NexusTextField(
          hint: 'Buscar por producto, marca o tienda',
          prefixIcon: Icons.search,
          onChanged: _onSearch,
          textInputAction: TextInputAction.search,
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (label, moderation) in <(String, OfferModeration?)>[
                ('Todas${count('all')}', null),
                ('Piden revisión${count('review')}', OfferModeration.review),
                ('Ocultas${count('hidden')}', OfferModeration.hidden),
                ('Rechazadas${count('rejected')}', OfferModeration.rejected),
                ('Aprobadas${count('approved')}', OfferModeration.approved),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: query.moderation == moderation,
                    onSelected: (_) => notifier.setModeration(moderation),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text('Con alertas${count('flagged')}'),
                  selected: query.anyFlag,
                  onSelected: (selected) => notifier.setFlag(null, anyFlag: selected),
                ),
              ),
              for (final flag in QualityFlag.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(flag.label),
                    selected: query.flag == flag,
                    onSelected: (selected) => notifier.setFlag(selected ? flag : null),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        switch (offers) {
          AsyncValue(value: final list?) when list.items.isEmpty => const NexusEmptyState(
            message: 'No hay publicaciones con ese filtro.',
          ),
          AsyncValue(value: final list?) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                list.page.total == 1 ? '1 publicación' : '${list.page.total} publicaciones',
                style: const TextStyle(fontSize: 11, color: Colors.white54),
              ),
              const SizedBox(height: 8),
              for (final offer in list.items) _OfferTile(key: ValueKey(offer.offerId), offer: offer),
              if (list.page.hasMore)
                NexusOutlineButton(
                  label: list.loadingMore ? 'Cargando…' : 'Ver más',
                  onPressed: list.loadingMore ? null : _loadMore,
                ),
              const SizedBox(height: 20),
            ],
          ),
          AsyncValue(:final error?) => NexusErrorState(
            message: 'No se pudieron cargar las publicaciones.\n${AuthErrorBanner.messageFor(error)}',
            onRetry: () => ref.invalidate(adminOffersProvider),
          ),
          _ => const NexusLoading(),
        },
      ],
    );
  }
}

class _OfferTile extends StatelessWidget {
  const _OfferTile({super.key, required this.offer});

  final AdminOffer offer;

  @override
  Widget build(BuildContext context) {
    final category = offer.category == null ? null : ProductVisuals.forCategory(offer.category!).categoryLabel;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () =>
            Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => AdminOfferScreen(offerId: offer.offerId))),
        child: NexusCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  offer.productName,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  [offer.providerName, offer.brand, ?category].join(' · '),
                  style: const TextStyle(fontSize: 11, color: NexusColors.textDim),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatPrice(offer.priceCents)} · ${offer.stockUnits} unidades',
                  style: const TextStyle(fontSize: 12, color: NexusColors.text),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    NexusTag(offer.moderation.label.toUpperCase(), color: moderationColor(offer.moderation)),
                    if (offer.moderation == OfferModeration.approved && !offer.visible)
                      const NexusTag('NO VISIBLE', color: NexusColors.textDim),
                  ],
                ),
                if (offer.flags.isNotEmpty) ...[const SizedBox(height: 6), QualityFlagTags(offer.flags)],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
