import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/format_price.dart';
import '../../../core/utils/validators.dart';
import '../../../theme/nexus_theme.dart';
import '../../../widgets/nexus_empty_state.dart';
import '../../../widgets/nexus_error_state.dart';
import '../../../widgets/nexus_loading.dart';
import '../../../widgets/nexus_page.dart';
import '../../../widgets/nexus_widgets.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../../cart/cart_providers.dart';
import '../../cart/domain/cart_models.dart';
import '../../cart/presentation/cart_actions.dart';
import '../../profile/domain/profile_models.dart';
import '../../profile/presentation/address_form_screen.dart';
import '../../profile/profile_providers.dart';
import '../checkout_providers.dart';
import '../domain/checkout_models.dart';
import 'payment_result_view.dart';

/// Confirmar la compra (HU-010, RF-056): dirección, contacto y facturación,
/// resumen por proveedor y pago con Wompi. Se llega con sesión (RN-027).
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _document = TextEditingController();
  var _documentType = DocumentType.cc;
  String? _addressId;

  @override
  void initState() {
    super.initState();
    // Se llena con el perfil una sola vez; después manda lo que escriba.
    ref.listenManual(profileProvider, fireImmediately: true, (_, next) {
      final profile = next.value;
      if (profile == null) return;
      if (_name.text.isEmpty) _name.text = profile.fullName;
      if (_email.text.isEmpty) _email.text = profile.email;
      if (_phone.text.isEmpty) _phone.text = profile.phone ?? '';
    });
  }

  @override
  void dispose() {
    for (final controller in [_name, _email, _phone, _document]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _selectedAddress(List<Address> addresses) {
    if (addresses.any((address) => address.id == _addressId)) return _addressId;
    for (final address in addresses) {
      if (address.isDefault) return address.id;
    }
    return addresses.isEmpty ? null : addresses.first.id;
  }

  Future<void> _addAddress() => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const AddressFormScreen()));

  Future<void> _pay(CartState cart, String? addressId) async {
    if (!_formKey.currentState!.validate()) return;
    if (addressId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega una dirección de entrega.')),
      );
      return;
    }
    final controller = ref.read(checkoutControllerProvider.notifier);
    final session = await controller.start(
      addressId: addressId,
      contact: CheckoutContact(
        fullName: _name.text,
        email: _email.text,
        phone: Validators.normalizePhone(_phone.text),
        documentType: _documentType,
        documentNumber: _document.text,
      ),
      expectedTotalCents: cart.subtotalCents,
    );
    if (session == null || !mounted) return;
    final transactionId = await ref
        .read(paymentLauncherProvider)
        .open(context, session);
    if (!mounted) return;
    await controller.verify(transactionId: transactionId);
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(checkoutControllerProvider);
    if (flow.step == CheckoutStep.done) {
      return NexusPage(
        title: 'RESULTADO DEL PAGO',
        showBack: false,
        showCart: false,
        children: [PaymentResultView(flow: flow)],
      );
    }

    final cart = ref.watch(cartControllerProvider);
    final addresses = ref.watch(addressesProvider);

    return PopScope(
      // No se sale a mitad del pago: el resultado llegaría a una pantalla cerrada.
      canPop: !flow.isBusy,
      child: NexusPage(
        title: 'FINALIZAR COMPRA',
        showBack: !flow.isBusy,
        showCart: false,
        children: [
          if (cart.value case final state?)
            if (!state.canCheckout)
              NexusEmptyState(
                message: state.isEmpty
                    ? 'Tu carrito está vacío.'
                    : 'Algunos productos de tu carrito cambiaron. Revísalo antes de pagar.',
                actionLabel: 'Volver al carrito',
                onAction: () => Navigator.of(context).maybePop(),
              )
            else
              _form(state, addresses, flow)
          else if (cart.hasError)
            NexusErrorState(
              message: cartErrorMessage(cart.error!),
              onRetry: () => ref.invalidate(cartControllerProvider),
            )
          else
            const NexusLoading(),
        ],
      ),
    );
  }

  Widget _form(
    CartState cart,
    AsyncValue<List<Address>> addresses,
    CheckoutFlow flow,
  ) {
    final list = addresses.value ?? const <Address>[];
    final addressId = _selectedAddress(list);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle('DIRECCIÓN DE ENTREGA'),
          if (addresses.isLoading && list.isEmpty)
            const NexusLoading()
          else ...[
            RadioGroup<String>(
              groupValue: addressId,
              onChanged: (value) => setState(() => _addressId = value),
              child: Column(
                children: [
                  for (final address in list)
                    RadioListTile<String>(
                      value: address.id,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${address.label} · ${address.recipientName}',
                        style: const TextStyle(fontSize: 12.5, color: NexusColors.text),
                      ),
                      subtitle: Text(
                        address.summary,
                        style: const TextStyle(fontSize: 11, color: NexusColors.textDim),
                      ),
                    ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: flow.isBusy ? null : _addAddress,
                icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                label: Text(list.isEmpty ? 'Agregar una dirección' : 'Agregar otra dirección'),
              ),
            ),
          ],
          const SizedBox(height: 8),
          const _SectionTitle('CONTACTO Y FACTURACIÓN'),
          AuthField(
            label: 'NOMBRE COMPLETO',
            field: NexusTextField(
              hint: 'Como aparece en tu documento',
              controller: _name,
              enabled: !flow.isBusy,
              validator: Validators.text(field: 'tu nombre', min: 2, max: 120),
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
            ),
          ),
          AuthField(
            label: 'CORREO',
            field: NexusTextField(
              hint: 'tu@correo.com',
              controller: _email,
              enabled: !flow.isBusy,
              validator: Validators.email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
            ),
          ),
          AuthField(
            label: 'TELÉFONO',
            field: NexusTextField(
              hint: '3001234567',
              controller: _phone,
              enabled: !flow.isBusy,
              validator: Validators.phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.telephoneNumber],
            ),
          ),
          AuthField(
            label: 'TIPO DE DOCUMENTO',
            field: DropdownButtonFormField<DocumentType>(
              initialValue: _documentType,
              isExpanded: true,
              dropdownColor: NexusColors.card,
              items: [
                for (final type in DocumentType.values)
                  DropdownMenuItem(value: type, child: Text(type.label)),
              ],
              onChanged: flow.isBusy
                  ? null
                  : (value) => setState(() => _documentType = value!),
            ),
          ),
          AuthField(
            label: 'NÚMERO DE DOCUMENTO',
            field: NexusTextField(
              hint: 'Sin puntos ni espacios',
              controller: _document,
              enabled: !flow.isBusy,
              validator: Validators.document,
              keyboardType: _documentType == DocumentType.pp
                  ? TextInputType.text
                  : TextInputType.number,
              textInputAction: TextInputAction.done,
            ),
          ),
          const SizedBox(height: 8),
          const _SectionTitle('RESUMEN'),
          _OrderSummary(cart: cart),
          const SizedBox(height: 16),
          if (flow.failure case final failure?) AuthErrorBanner(failure),
          NexusPrimaryButton(
            label: 'PAGAR ${formatPrice(cart.subtotalCents)}',
            icon: Icons.lock_outline,
            loading: flow.isBusy,
            onPressed: () => _pay(cart, addressId),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pagas en Wompi con tarjeta, PSE o Nequi. NEXUS no guarda los '
            'datos de tu medio de pago.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10.5, color: NexusColors.textFaint),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.4,
          color: NexusColors.textDim,
        ),
      ),
    );
  }
}

/// Un envío por proveedor (S-06) y el total, con el IVA incluido (RN-001).
class _OrderSummary extends StatelessWidget {
  const _OrderSummary({required this.cart});

  final CartState cart;

  @override
  Widget build(BuildContext context) {
    final shipments = cart.groups.length;
    return NexusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          for (final (index, group) in cart.groups.indexed) ...[
            Text(
              shipments == 1
                  ? 'Envío de ${group.providerName}'
                  : 'Envío ${index + 1} de $shipments · ${group.providerName}',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: NexusColors.text,
              ),
            ),
            for (final item in group.items)
              NexusSpecRow(
                '${item.quantity} × ${item.productName}',
                formatPrice(item.subtotalCents),
              ),
            const SizedBox(height: 6),
          ],
          const Divider(color: NexusColors.border, height: 16),
          const NexusSpecRow('Envío', 'Sin costo adicional', valueColor: NexusColors.textDim),
          NexusSpecRow(
            'Total (IVA incluido)',
            formatPrice(cart.subtotalCents),
            valueColor: NexusColors.cyan,
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
