import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/utils/validators.dart';
import '../../../widgets/nexus_error_state.dart';
import '../../../widgets/nexus_loading.dart';
import '../../../widgets/nexus_widgets.dart';
import '../auth_providers.dart';
import '../domain/auth_models.dart';
import 'auth_widgets.dart';

/// Registro con aceptación de términos y política de datos (HU-001, RF-007).
/// Devuelve `true` al cerrar si la cuenta quedó con sesión iniciada.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  var _accepted = false;
  var _showConsentError = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit(List<LegalDocument> documents) async {
    final formValid = _formKey.currentState!.validate();
    setState(() => _showConsentError = !_accepted);
    if (!formValid || !_accepted) return;

    final result = await ref
        .read(signUpControllerProvider.notifier)
        .submit(
          fullName: _name.text,
          email: _email.text,
          password: _password.text,
          acceptedDocuments: documents,
        );
    if (!mounted) return;
    if (ref.read(signUpControllerProvider).error is ConsentRequiredFailure) {
      // Puede haber una versión nueva de los documentos: se recargan para que
      // el usuario los lea y acepte otra vez.
      ref.invalidate(legalDocumentsProvider);
      setState(() => _accepted = false);
    }
    if (result == null) return;

    if (result == SignUpResult.confirmationRequired) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirma tu correo'),
          content: Text(
            'Te enviamos un enlace a ${_email.text.trim()}. '
            'Ábrelo para activar tu cuenta y luego inicia sesión.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop(false);
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(signUpControllerProvider);
    final documents = ref.watch(legalDocumentsProvider);

    return AuthScaffold(
      title: 'CREAR CUENTA',
      subtitle: 'Regístrate para comprar y recibir recomendaciones.',
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (action.error case final error?) AuthErrorBanner(error),
              AuthField(
                label: 'NOMBRE',
                field: NexusTextField(
                  hint: 'Tu nombre completo',
                  controller: _name,
                  validator: Validators.text(field: 'tu nombre', min: 2, max: 120),
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                ),
              ),
              AuthField(
                label: 'EMAIL',
                field: NexusTextField(
                  hint: 'tu@correo.com',
                  controller: _email,
                  validator: Validators.email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                ),
              ),
              AuthField(
                label: 'CONTRASEÑA',
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
                ),
              ),
              documents.when(
                loading: () => const NexusLoading(),
                error: (error, _) => NexusErrorState(
                  message: 'No se pudieron cargar los términos.\n'
                      '${AuthErrorBanner.messageFor(error)}',
                  onRetry: () => ref.invalidate(legalDocumentsProvider),
                ),
                data: (documents) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LegalConsentCheckbox(
                      documents: documents,
                      value: _accepted,
                      showError: _showConsentError && !_accepted,
                      onChanged: (value) => setState(() => _accepted = value),
                    ),
                    const SizedBox(height: 16),
                    NexusPrimaryButton(
                      label: 'CREAR CUENTA',
                      loading: action.isLoading,
                      onPressed: () => _submit(documents),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AuthLink(
                prefix: '¿Ya tienes cuenta? ',
                label: 'Ingresar',
                onTap: () => Navigator.of(context).maybePop(false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
