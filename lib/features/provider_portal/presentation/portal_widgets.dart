import 'package:flutter/material.dart';

import '../../../theme/nexus_theme.dart';
import '../../../widgets/nexus_widgets.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../domain/portal_models.dart';

String offerStatusLabel(OfferStatus status) => switch (status) {
  OfferStatus.draft => 'Borrador',
  OfferStatus.published => 'Publicada',
  OfferStatus.paused => 'Pausada',
  OfferStatus.retired => 'Retirada',
};

Color offerStatusColor(OfferStatus status) => switch (status) {
  OfferStatus.published => NexusColors.green,
  OfferStatus.retired => NexusColors.pink,
  OfferStatus.draft || OfferStatus.paused => NexusColors.textDim,
};

/// Pesos escritos por la tienda ("2.500.000" o "2500000") en centavos de
/// COP. `null` si está vacío.
int? pesosToCents(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty || digits.length > 10) return null;
  return int.parse(digits) * 100;
}

int? _units(String text) {
  final digits = text.trim();
  return RegExp(r'^[0-9]{1,6}$').hasMatch(digits) ? int.parse(digits) : null;
}

/// Campos de la oferta: precio, precio anterior (descuento), existencias,
/// estado y código interno. Valida como el backend.
class OfferFieldsData {
  OfferFieldsData([MyOffer? current])
    : price = TextEditingController(text: current == null ? '' : '${current.priceCents ~/ 100}'),
      oldPrice = TextEditingController(
        text: current?.oldPriceCents == null ? '' : '${current!.oldPriceCents! ~/ 100}',
      ),
      stock = TextEditingController(text: current == null ? '' : '${current.stockUnits}'),
      sku = TextEditingController(text: current?.externalSku ?? ''),
      status = current == null || current.status == OfferStatus.retired
          ? OfferStatus.published
          : current.status;

  final TextEditingController price;
  final TextEditingController oldPrice;
  final TextEditingController stock;
  final TextEditingController sku;
  OfferStatus status;

  OfferInput toInput() => OfferInput(
    priceCents: pesosToCents(price.text)!,
    oldPriceCents: pesosToCents(oldPrice.text),
    stockUnits: _units(stock.text)!,
    status: status,
    externalSku: sku.text.trim().isEmpty ? null : sku.text.trim(),
  );

  void dispose() {
    price.dispose();
    oldPrice.dispose();
    stock.dispose();
    sku.dispose();
  }
}

class OfferFields extends StatelessWidget {
  const OfferFields({super.key, required this.data, required this.onStatusChanged});

  final OfferFieldsData data;
  final ValueChanged<OfferStatus> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthField(
          label: 'PRECIO (PESOS)',
          field: NexusTextField(
            hint: 'Ej. 2500000',
            controller: data.price,
            keyboardType: TextInputType.number,
            validator: (value) {
              final cents = pesosToCents(value ?? '');
              return cents == null || cents <= 0 ? 'Escribe el precio en pesos.' : null;
            },
          ),
        ),
        AuthField(
          label: 'PRECIO ANTERIOR (OPCIONAL, PARA EL DESCUENTO)',
          field: NexusTextField(
            hint: 'Déjalo vacío si no hay descuento',
            controller: data.oldPrice,
            keyboardType: TextInputType.number,
            validator: (value) {
              final old = pesosToCents(value ?? '');
              final price = pesosToCents(data.price.text);
              if (old == null || price == null) return null;
              return old <= price ? 'Debe ser mayor que el precio actual.' : null;
            },
          ),
        ),
        AuthField(
          label: 'EXISTENCIAS (UNIDADES)',
          field: NexusTextField(
            hint: 'Ej. 12',
            controller: data.stock,
            keyboardType: TextInputType.number,
            validator: (value) {
              final units = _units(value ?? '');
              return units == null || units > 100000 ? 'Escribe un número entero de 0 a 100000.' : null;
            },
          ),
        ),
        const NexusFieldLabel('ESTADO'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            for (final status in const [OfferStatus.published, OfferStatus.paused, OfferStatus.draft])
              ChoiceChip(
                label: Text(offerStatusLabel(status)),
                selected: data.status == status,
                onSelected: (_) => onStatusChanged(status),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          switch (data.status) {
            OfferStatus.published => 'Se ve en el catálogo de inmediato.',
            OfferStatus.paused => 'No se ve en el catálogo hasta que la publiques.',
            _ => 'Queda guardada sin publicar.',
          },
          style: const TextStyle(fontSize: 11, color: NexusColors.textDim),
        ),
        const SizedBox(height: 14),
        AuthField(
          label: 'CÓDIGO INTERNO (OPCIONAL)',
          field: NexusTextField(
            hint: 'El SKU de tu tienda',
            controller: data.sku,
            validator: (value) =>
                (value?.trim().length ?? 0) > 64 ? 'Admite hasta 64 caracteres.' : null,
          ),
        ),
      ],
    );
  }
}
