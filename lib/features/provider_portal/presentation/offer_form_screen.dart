import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/nexus_theme.dart';
import '../../../widgets/nexus_page.dart';
import '../../../widgets/nexus_widgets.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../domain/portal_models.dart';
import '../provider_portal_providers.dart';
import 'my_offer_screen.dart';
import 'portal_widgets.dart';

/// Oferta de la tienda sobre un producto: publicarla (o volver a publicar una
/// retirada) o editar su precio, descuento, stock y estado. Solo cambia la
/// oferta de esta tienda; las de las demás quedan igual.
class OfferFormScreen extends ConsumerStatefulWidget {
  const OfferFormScreen({
    super.key,
    required this.productId,
    required this.productName,
    this.current,
  });

  final String productId;
  final String productName;

  /// La oferta que se edita; sin ella se publica una nueva.
  final MyOffer? current;

  @override
  ConsumerState<OfferFormScreen> createState() => _OfferFormScreenState();
}

class _OfferFormScreenState extends ConsumerState<OfferFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _offer = OfferFieldsData(widget.current);

  bool get _editing => widget.current != null;

  @override
  void dispose() {
    _offer.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final input = _offer.toInput();
    final result = await ref.read(portalActionControllerProvider.notifier).run(
      (repository) => _editing
          ? repository.updateOffer(widget.productId, input)
          : repository.createOffer(widget.productId, input),
    );
    if (result == null || !mounted) return;

    final navigator = Navigator.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(_editing ? 'Oferta actualizada.' : 'Oferta publicada.')));
    if (_editing) {
      navigator.pop();
    } else {
      navigator.pushReplacement(
        MaterialPageRoute<void>(builder: (_) => MyOfferScreen(productId: widget.productId)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(portalActionControllerProvider);

    return NexusPage(
      title: _editing ? 'EDITAR OFERTA' : 'PUBLICAR OFERTA',
      showBack: true,
      showCart: false,
      children: [
        Text(
          widget.productName,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 4),
        const Text(
          'Solo cambias la oferta de tu tienda: precio, descuento, existencias y estado.',
          style: TextStyle(fontSize: 11.5, color: NexusColors.textDim),
        ),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (action.error case final error?) AuthErrorBanner(error),
              OfferFields(
                data: _offer,
                onStatusChanged: (status) => setState(() => _offer.status = status),
              ),
              const SizedBox(height: 8),
              NexusPrimaryButton(
                label: _editing ? 'GUARDAR CAMBIOS' : 'PUBLICAR',
                loading: action.isLoading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
