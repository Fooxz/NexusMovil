import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/utils/validators.dart';
import '../../../theme/nexus_theme.dart';
import '../../../widgets/nexus_page.dart';
import '../../../widgets/nexus_widgets.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../admin_providers.dart';
import '../domain/admin_models.dart';
import 'temporary_password_dialog.dart';

String? _taxId(String? value) => RegExp(r'^[0-9]{6,12}(-[0-9])?$').hasMatch(value?.trim() ?? '')
    ? null
    : 'Escribe el NIT con el formato 900123456-7.';

/// Crear una tienda verificada con su cuenta, o editar sus datos. El nombre
/// visible es el que ven los clientes en cada tarjeta.
class AdminStoreFormScreen extends ConsumerStatefulWidget {
  const AdminStoreFormScreen.create({super.key}) : current = null;

  const AdminStoreFormScreen.edit({super.key, required AdminStore this.current});

  final AdminStore? current;

  @override
  ConsumerState<AdminStoreFormScreen> createState() => _AdminStoreFormScreenState();
}

class _AdminStoreFormScreenState extends ConsumerState<AdminStoreFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _legalName = TextEditingController(text: widget.current?.legalName ?? '');
  late final _displayName = TextEditingController(text: widget.current?.displayName ?? '');
  late final _taxIdField = TextEditingController(text: widget.current?.taxId ?? '');
  late final _contactEmail = TextEditingController(text: widget.current?.contactEmail ?? '');
  late final _note = TextEditingController(text: widget.current?.verificationNote ?? '');
  final _accountEmail = TextEditingController();
  final _accountName = TextEditingController();

  bool get _editing => widget.current != null;

  @override
  void dispose() {
    for (final controller in [_legalName, _displayName, _taxIdField, _contactEmail, _note, _accountEmail, _accountName]) {
      controller.dispose();
    }
    super.dispose();
  }

  StoreInput get _store => StoreInput(
    legalName: _legalName.text,
    displayName: _displayName.text,
    taxId: _taxIdField.text,
    contactEmail: _contactEmail.text,
    verificationNote: _note.text,
  );

  Future<void> _submit({bool confirmSimilarName = false}) async {
    if (!_formKey.currentState!.validate()) return;
    final actions = ref.read(adminActionControllerProvider.notifier);
    final navigator = Navigator.of(context);

    if (_editing) {
      final updated = await actions.run(
        (repository) => repository.updateStore(widget.current!.id, _store, confirmSimilarName: confirmSimilarName),
        storeId: (store) => store.id,
      );
      if (!mounted) return;
      if (updated != null) {
        navigator.pop();
        return;
      }
    } else {
      final account = NewAccountInput(email: _accountEmail.text, fullName: _accountName.text);
      final result = await actions.run(
        (repository) => repository.createStore(_store, account, confirmSimilarName: confirmSimilarName),
        storeId: (result) => result.store.id,
      );
      if (!mounted) return;
      if (result != null) {
        await showTemporaryPassword(
          context,
          storeName: result.store.displayName,
          accountEmail: result.store.accountEmail ?? account.email.trim(),
          password: result.temporaryPassword,
        );
        if (mounted) navigator.pop();
        return;
      }
    }

    if (ref.read(adminActionControllerProvider).error case SimilarStoreNameFailure(:final userMessage)) {
      actions.clearError();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Nombre parecido'),
          content: Text('$userMessage\n\nDos negocios distintos pueden llamarse igual; '
              'considera agregar la ciudad para que los clientes los distingan.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cambiar nombre')),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Es otro negocio')),
          ],
        ),
      );
      if (confirmed == true && mounted) await _submit(confirmSimilarName: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(adminActionControllerProvider);

    return NexusPage(
      title: _editing ? 'EDITAR TIENDA' : 'CREAR TIENDA',
      showBack: true,
      showCart: false,
      children: [
        if (!_editing)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Crea la tienda después de verificar que existe. Su cuenta recibe una contraseña '
              'temporal que debe cambiar en su primer ingreso.',
              style: TextStyle(fontSize: 12, color: NexusColors.textDim),
            ),
          ),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (action.error case final error?) AuthErrorBanner(error),
              const NexusUnderlineTitle('TIENDA'),
              const SizedBox(height: 8),
              AuthField(
                label: 'RAZÓN SOCIAL',
                field: NexusTextField(
                  hint: 'Ej. Mundo PC Colombia S.A.S.',
                  controller: _legalName,
                  validator: Validators.text(field: 'la razón social', min: 2, max: 160),
                ),
              ),
              AuthField(
                label: 'NOMBRE VISIBLE (EL QUE VEN LOS CLIENTES)',
                field: NexusTextField(
                  hint: 'Ej. Mundo PC',
                  controller: _displayName,
                  validator: Validators.text(field: 'el nombre visible', min: 2, max: 60),
                ),
              ),
              AuthField(
                label: 'NIT',
                field: NexusTextField(hint: 'Ej. 900123456-7', controller: _taxIdField, validator: _taxId),
              ),
              AuthField(
                label: 'CORREO DE CONTACTO',
                field: NexusTextField(
                  hint: 'ventas@tienda.com',
                  controller: _contactEmail,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                ),
              ),
              AuthField(
                label: 'CÓMO SE VERIFICÓ (OPCIONAL)',
                field: NexusTextField(
                  hint: 'Ej. Visita al local, RUT y cámara de comercio',
                  controller: _note,
                  validator: (value) => Validators.optionalText(value, max: 500),
                ),
              ),
              if (!_editing) ...[
                const NexusUnderlineTitle('CUENTA DE LA TIENDA'),
                const SizedBox(height: 8),
                AuthField(
                  label: 'CORREO DE LA CUENTA',
                  field: NexusTextField(
                    hint: 'dueno@tienda.com',
                    controller: _accountEmail,
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.email,
                  ),
                ),
                AuthField(
                  label: 'NOMBRE DE QUIEN LA OPERA',
                  field: NexusTextField(
                    hint: 'Nombre completo',
                    controller: _accountName,
                    validator: Validators.text(field: 'el nombre', min: 2, max: 120),
                  ),
                ),
              ],
              NexusPrimaryButton(
                label: _editing ? 'GUARDAR CAMBIOS' : 'CREAR TIENDA Y CUENTA',
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

/// Cuenta para una tienda que ya existía sin cuenta (las cargadas antes de
/// los roles).
class AdminAccountFormScreen extends ConsumerStatefulWidget {
  const AdminAccountFormScreen({super.key, required this.store});

  final AdminStore store;

  @override
  ConsumerState<AdminAccountFormScreen> createState() => _AdminAccountFormScreenState();
}

class _AdminAccountFormScreenState extends ConsumerState<AdminAccountFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _name = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final account = NewAccountInput(email: _email.text, fullName: _name.text);
    final navigator = Navigator.of(context);
    final result = await ref.read(adminActionControllerProvider.notifier).run(
      (repository) => repository.createAccount(widget.store.id, account),
      storeId: (result) => result.store.id,
    );
    if (result == null || !mounted) return;
    await showTemporaryPassword(
      context,
      storeName: result.store.displayName,
      accountEmail: result.store.accountEmail ?? account.email.trim(),
      password: result.temporaryPassword,
    );
    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(adminActionControllerProvider);

    return NexusPage(
      title: 'CREAR CUENTA',
      showBack: true,
      showCart: false,
      children: [
        Text(
          'Cuenta para ${widget.store.displayName}. La tienda conserva su estado y sus ofertas.',
          style: const TextStyle(fontSize: 12, color: NexusColors.textDim),
        ),
        const SizedBox(height: 12),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (action.error case final error?) AuthErrorBanner(error),
              AuthField(
                label: 'CORREO DE LA CUENTA',
                field: NexusTextField(
                  hint: 'dueno@tienda.com',
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                ),
              ),
              AuthField(
                label: 'NOMBRE DE QUIEN LA OPERA',
                field: NexusTextField(
                  hint: 'Nombre completo',
                  controller: _name,
                  validator: Validators.text(field: 'el nombre', min: 2, max: 120),
                ),
              ),
              NexusPrimaryButton(label: 'CREAR CUENTA', loading: action.isLoading, onPressed: _submit),
            ],
          ),
        ),
      ],
    );
  }
}
