import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/validators.dart';
import '../../../widgets/nexus_widgets.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../account_providers.dart';

/// Nueva contraseña con confirmación. Lo usan el primer ingreso de una tienda
/// (contraseña temporal) y el cambio voluntario desde la cuenta.
class ChangePasswordForm extends ConsumerStatefulWidget {
  const ChangePasswordForm({
    super.key,
    this.onChanged,
    this.submitLabel = 'CAMBIAR CONTRASEÑA',
  });

  /// Se llama después de cambiarla.
  final VoidCallback? onChanged;
  final String submitLabel;

  @override
  ConsumerState<ChangePasswordForm> createState() => _ChangePasswordFormState();
}

class _ChangePasswordFormState extends ConsumerState<ChangePasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref
        .read(changePasswordControllerProvider.notifier)
        .submit(_password.text);
    if (ok && mounted) widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(changePasswordControllerProvider);

    return AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (action.error case final error?) AuthErrorBanner(error),
            AuthField(
              label: 'NUEVA CONTRASEÑA',
              field: NexusTextField(
                hint: 'Mínimo 8 caracteres, con letras y números',
                obscure: true,
                controller: _password,
                validator: Validators.password,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
              ),
            ),
            AuthField(
              label: 'CONFIRMAR CONTRASEÑA',
              field: NexusTextField(
                hint: 'Repite la contraseña',
                obscure: true,
                controller: _confirmation,
                validator: Validators.matches(() => _password.text),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
            ),
            NexusPrimaryButton(
              label: widget.submitLabel,
              loading: action.isLoading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// Cambio voluntario de contraseña, desde la pestaña CUENTA.
class ChangePasswordScreen extends StatelessWidget {
  const ChangePasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'CAMBIAR CONTRASEÑA',
      subtitle: 'Elige una contraseña nueva para tu cuenta.',
      child: ChangePasswordForm(
        onChanged: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contraseña actualizada.')),
          );
          Navigator.of(context).pop();
        },
      ),
    );
  }
}
