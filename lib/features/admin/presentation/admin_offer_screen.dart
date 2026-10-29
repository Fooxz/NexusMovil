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
import '../../provider_portal/domain/portal_models.dart';
import '../../provider_portal/presentation/attribute_fields.dart';
import '../../provider_portal/presentation/portal_widgets.dart';
import '../../provider_portal/provider_portal_providers.dart';
import '../../vendor/presentation/vendor_widgets.dart';
import '../admin_console_providers.dart';
import '../domain/admin_console_models.dart';
import 'admin_product_form_screen.dart';
import 'admin_store_screen.dart';
import 'admin_widgets.dart';

/// Una publicación vista por el administrador: la oferta, sus alertas de
/// calidad, la ficha técnica, las otras tiendas que venden el producto y las
/// acciones de moderación (aprobar, ocultar pidiendo ajustes, rechazar).
class AdminOfferScreen extends ConsumerWidget {
  const AdminOfferScreen({super.key, required this.offerId});

  final String offerId;

  static String _flagHelp(QualityFlag flag) => switch (flag) {
    QualityFlag.incomplete => 'Le falta un atributo obligatorio: el PC Builder no puede validar su compatibilidad.',
    QualityFlag.priceAnomaly =>
      'El precio es menos de la mitad o más del doble de la mediana de las tiendas que venden el producto.',
    QualityFlag.duplicate => 'Hay otra ficha de la misma categoría con el mismo nombre.',
  };

  Future<void> _moderate(BuildContext context, WidgetRef ref, AdminOffer offer, ModerationAction action) async {
    String? reason;
    if (action != ModerationAction.approve) {
      reason = await showReasonDialog(
        context,
        title: action == ModerationAction.hide ? 'Ocultar y pedir ajustes' : 'Rechazar publicación',
        message: action == ModerationAction.hide
            ? '${offer.providerName} verá el motivo y podrá pedir la revisión al corregirla.'
            : 'La publicación sale del catálogo y la tienda no puede pedir revisión. ${offer.providerName} verá el motivo.',
        label: 'Motivo para la tienda',
        action: action == ModerationAction.hide ? 'Ocultar' : 'Rechazar',
      );
      if (reason == null) return;
    }
    if (!context.mounted) return;
    final result = await ref.read(adminConsoleActionProvider.notifier).moderate(offerId, action, reason: reason);
    if (!context.mounted) return;
    final error = ref.read(adminConsoleActionProvider).error;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            result == null
                ? AuthErrorBanner.messageFor(error ?? Object())
                : switch (action) {
                    ModerationAction.approve => 'Publicación aprobada.',
                    ModerationAction.hide => 'Publicación oculta: la tienda verá el motivo.',
                    ModerationAction.reject => 'Publicación rechazada.',
                  },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(adminOfferDetailProvider(offerId));
    final busy = ref.watch(adminConsoleActionProvider).isLoading;

    return NexusPage(
      title: 'PUBLICACIÓN',
      showBack: true,
      showCart: false,
      children: [
        detail.when(
          loading: () => const NexusLoading(),
          error: (error, _) => NexusErrorState(
            message: 'No se pudo cargar la publicación.\n${AuthErrorBanner.messageFor(error)}',
            onRetry: () => ref.invalidate(adminOfferDetailProvider(offerId)),
          ),
          data: (detail) {
            final offer = detail.offer;
            final category = offer.category;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  offer.productName,
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    offer.brand,
                    ?offer.model,
                    if (category != null) ProductVisuals.forCategory(category).categoryLabel,
                  ].join(' · '),
                  style: const TextStyle(fontSize: 12, color: NexusColors.textDim),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    NexusTag(offer.moderation.label.toUpperCase(), color: moderationColor(offer.moderation)),
                    NexusTag(
                      offer.visible ? 'VISIBLE EN EL CATÁLOGO' : 'NO VISIBLE',
                      color: offer.visible ? NexusColors.green : NexusColors.textDim,
                    ),
                  ],
                ),
                if (offer.moderationReason case final reason?) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Motivo enviado a la tienda: $reason',
                    style: const TextStyle(fontSize: 12, color: NexusColors.text),
                  ),
                ],
                if (offer.flags.isNotEmpty) ...[
                  const VendorSectionTitle('ALERTAS DE CALIDAD'),
                  for (final flag in offer.flags)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.flag_outlined,
                            size: 16,
                            color: flag == QualityFlag.priceAnomaly ? amber : NexusColors.pink,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${flag.label}. ${_flagHelp(flag)}',
                              style: const TextStyle(fontSize: 12, color: NexusColors.text),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                const VendorSectionTitle('OFERTA'),
                NexusCard(
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () => Navigator.of(context)
                            .push(MaterialPageRoute<void>(builder: (_) => AdminStoreScreen(storeId: offer.providerId))),
                        child: NexusSpecRow('TIENDA', '${offer.providerName} ›'),
                      ),
                      const Divider(color: NexusColors.border, height: 1),
                      NexusSpecRow('PRECIO', formatPrice(offer.priceCents)),
                      if (offer.oldPriceCents case final old?) ...[
                        const Divider(color: NexusColors.border, height: 1),
                        NexusSpecRow('PRECIO ANTERIOR', formatPrice(old)),
                      ],
                      const Divider(color: NexusColors.border, height: 1),
                      NexusSpecRow('EXISTENCIAS', '${offer.stockUnits} unidades'),
                      const Divider(color: NexusColors.border, height: 1),
                      NexusSpecRow(
                        'ESTADO',
                        offerStatusLabel(offer.status),
                        valueColor: offerStatusColor(offer.status),
                      ),
                      const Divider(color: NexusColors.border, height: 1),
                      NexusSpecRow('ACTUALIZADA', formatDateTime(offer.updatedAt)),
                    ],
                  ),
                ),
                if (detail.otherOffers.isNotEmpty) ...[
                  const VendorSectionTitle('OTRAS TIENDAS CON ESTE PRODUCTO'),
                  AdminInfoCard(
                    rows: [
                      for (final other in detail.otherOffers)
                        (
                          other.providerName.toUpperCase(),
                          '${formatPrice(other.priceCents)} · ${other.stockUnits} u.'
                              '${other.moderation == OfferModeration.approved ? '' : ' · ${other.moderation.label}'}',
                        ),
                    ],
                  ),
                ],
                const VendorSectionTitle('FICHA TÉCNICA'),
                if (category == null)
                  const Text('Categoría desconocida.', style: TextStyle(fontSize: 12, color: NexusColors.textDim))
                else
                  _Attributes(detail: detail),
                const SizedBox(height: 16),
                if (offer.moderation != OfferModeration.approved)
                  NexusPrimaryButton(
                    label: offer.moderation == OfferModeration.review ? 'APROBAR CORRECCIÓN' : 'APROBAR Y MOSTRAR',
                    loading: busy,
                    onPressed: () => _moderate(context, ref, offer, ModerationAction.approve),
                  ),
                if (offer.moderation != OfferModeration.hidden) ...[
                  const SizedBox(height: 10),
                  NexusOutlineButton(
                    label: 'OCULTAR Y PEDIR AJUSTES',
                    onPressed: busy ? null : () => _moderate(context, ref, offer, ModerationAction.hide),
                  ),
                ],
                if (offer.moderation != OfferModeration.rejected) ...[
                  const SizedBox(height: 10),
                  NexusOutlineButton(
                    label: 'RECHAZAR PUBLICACIÓN',
                    color: NexusColors.pink,
                    borderColor: NexusColors.pink,
                    onPressed: busy ? null : () => _moderate(context, ref, offer, ModerationAction.reject),
                  ),
                ],
                if (category != null) ...[
                  const SizedBox(height: 10),
                  NexusOutlineButton(
                    label: 'CORREGIR FICHA DEL PRODUCTO',
                    onPressed: () =>
                        Navigator.of(context)
                            .push(MaterialPageRoute<void>(builder: (_) => AdminProductFormScreen(detail: detail))),
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

/// Atributos con las etiquetas de la plantilla; marca los obligatorios que
/// faltan.
class _Attributes extends ConsumerWidget {
  const _Attributes({required this.detail});

  final AdminOfferDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final template = ref.watch(attributeTemplateProvider(detail.offer.category!));
    return template.when(
      loading: () => const NexusLoading(),
      error: (error, _) => Text(
        'No se pudo cargar la plantilla. ${AuthErrorBanner.messageFor(error)}',
        style: const TextStyle(fontSize: 12, color: NexusColors.textDim),
      ),
      data: (definitions) => AdminInfoCard(
        rows: [
          for (final definition in definitions)
            (
              definition.label.toUpperCase(),
              switch (detail.attributes[definition.key]) {
                final Object value => AttributeValues.display(definition, value),
                null => definition.isRequired ? 'FALTA (obligatorio)' : '—',
              },
            ),
        ],
      ),
    );
  }
}
