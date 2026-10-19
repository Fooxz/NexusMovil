import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/validators.dart';
import '../../../theme/nexus_theme.dart';
import '../../../widgets/nexus_page.dart';
import '../../../widgets/nexus_widgets.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../domain/profile_models.dart';
import '../profile_providers.dart';

/// Crear o editar una dirección de entrega. Los campos inválidos se marcan
/// antes de enviar (HU-003).
class AddressFormScreen extends ConsumerStatefulWidget {
  const AddressFormScreen({super.key, this.address});

  /// Dirección a editar; `null` para crear una nueva.
  final Address? address;

  @override
  ConsumerState<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends ConsumerState<AddressFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _label = TextEditingController(text: widget.address?.label);
  late final _recipient = TextEditingController(
    text: widget.address?.recipientName,
  );
  late final _phone = TextEditingController(text: widget.address?.phone);
  late final _city = TextEditingController(text: widget.address?.city);
  late final _line = TextEditingController(text: widget.address?.addressLine);
  late final _details = TextEditingController(text: widget.address?.details);
  late String? _department = widget.address?.department;
  late bool _isDefault = widget.address?.isDefault ?? false;

  bool get _editing => widget.address != null;

  @override
  void dispose() {
    for (final controller in [_label, _recipient, _phone, _city, _line, _details]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref
        .read(addressFormControllerProvider.notifier)
        .save(
          AddressInput(
            label: _label.text,
            recipientName: _recipient.text,
            phone: _phone.text,
            department: _department!,
            city: _city.text,
            addressLine: _line.text,
            details: _details.text,
            isDefault: _isDefault,
          ),
          id: widget.address?.id,
        );
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(addressFormControllerProvider);
    final alreadyDefault = widget.address?.isDefault ?? false;

    return NexusPage(
      title: _editing ? 'EDITAR DIRECCIÓN' : 'NUEVA DIRECCIÓN',
      showBack: true,
      showCart: false,
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (action.error case final error?) AuthErrorBanner(error),
              AuthField(
                label: 'NOMBRE DE LA DIRECCIÓN',
                field: NexusTextField(
                  hint: 'Casa, Oficina…',
                  controller: _label,
                  validator: Validators.text(field: 'el nombre', max: 40),
                  textInputAction: TextInputAction.next,
                ),
              ),
              AuthField(
                label: 'QUIÉN RECIBE',
                field: NexusTextField(
                  hint: 'Nombre completo',
                  controller: _recipient,
                  validator: Validators.text(field: 'quién recibe', min: 2, max: 120),
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                ),
              ),
              AuthField(
                label: 'TELÉFONO DE CONTACTO',
                field: NexusTextField(
                  hint: '3001234567',
                  controller: _phone,
                  validator: Validators.phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.telephoneNumber],
                ),
              ),
              AuthField(
                label: 'DEPARTAMENTO',
                field: DropdownButtonFormField<String>(
                  initialValue: _department,
                  isExpanded: true,
                  dropdownColor: NexusColors.card,
                  hint: const Text('Elige un departamento'),
                  items: [
                    for (final department in colombianDepartments)
                      DropdownMenuItem(value: department, child: Text(department)),
                  ],
                  validator: (value) =>
                      value == null ? 'Elige un departamento.' : null,
                  onChanged: (value) => setState(() => _department = value),
                ),
              ),
              AuthField(
                label: 'CIUDAD O MUNICIPIO',
                field: NexusTextField(
                  hint: 'Medellín',
                  controller: _city,
                  validator: Validators.text(field: 'la ciudad', min: 2, max: 80),
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.addressCity],
                ),
              ),
              AuthField(
                label: 'DIRECCIÓN',
                field: NexusTextField(
                  hint: 'Calle 10 # 20-30',
                  controller: _line,
                  validator: Validators.text(field: 'la dirección', min: 5, max: 200),
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.streetAddressLine1],
                ),
              ),
              AuthField(
                label: 'DETALLES (OPCIONAL)',
                field: NexusTextField(
                  hint: 'Apartamento, torre, indicaciones',
                  controller: _details,
                  validator: (value) => Validators.optionalText(value),
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.streetAddressLine2],
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isDefault,
                // Para cambiar la predeterminada se marca otra dirección.
                onChanged: alreadyDefault
                    ? null
                    : (value) => setState(() => _isDefault = value),
                title: const Text(
                  'Usar como dirección predeterminada',
                  style: TextStyle(fontSize: 12.5, color: NexusColors.text),
                ),
              ),
              const SizedBox(height: 10),
              NexusPrimaryButton(
                label: _editing ? 'GUARDAR CAMBIOS' : 'GUARDAR DIRECCIÓN',
                loading: action.isLoading,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
