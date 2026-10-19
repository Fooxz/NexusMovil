import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/validators.dart';
import '../../../theme/nexus_theme.dart';
import '../../../widgets/nexus_widgets.dart';
import '../auth_providers.dart';
import '../data/mock_auth_repository.dart';
import 'auth_widgets.dart';

/// Recuperación de acceso (RF-003) con un código de 6 dígitos enviado al
/// correo. Al terminar deja la sesión iniciada y devuelve `true`.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailForm = GlobalKey<FormState>();
  final _resetForm = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  String? _sentTo;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (!(_emailForm.currentState?.validate() ?? true)) return;
    final email = _sentTo ?? _email.text.trim();
    final ok = await ref
        .read(passwordResetControllerProvider.notifier)
        .requestCode(email);
    if (ok && mounted) setState(() => _sentTo = email);
  }

  Future<void> _reset() async {
    if (!_resetForm.currentState!.validate()) return;
    final ok = await ref
        .read(passwordResetControllerProvider.notifier)
        .reset(
          email: _sentTo!,
          code: _code.text,
          newPassword: _password.text,
        );
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(passwordResetControllerProvider);
    final sentTo = _sentTo;

    return AuthScaffold(
      title: 'RECUPERAR ACCESO',
      subtitle: sentTo == null
          ? 'Te enviaremos un código para crear una contraseña nueva.'
          : 'Si $sentTo tiene una cuenta, te llegó un código de 6 dígitos.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (action.error case final error?) AuthErrorBanner(error),
          if (sentTo == null)
            Form(
              key: _emailForm,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthField(
                    label: 'EMAIL',
                    field: NexusTextField(
                      hint: 'tu@correo.com',
                      controller: _email,
                      validator: Validators.email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _requestCode(),
                      autofillHints: const [AutofillHints.email],
                    ),
                  ),
                  NexusPrimaryButton(
                    label: 'ENVIAR CÓDIGO',
                    loading: action.isLoading,
                    onPressed: _requestCode,
                  ),
                ],
              ),
            )
          else
            Form(
              key: _resetForm,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (ref.watch(authRepositoryProvider) is MockAuthRepository)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Modo sin backend: el código es '
                        '${MockAuthRepository.recoveryCode}.',
                        style: TextStyle(fontSize: 11, color: NexusColors.textDim),
                      ),
                    ),
                  AuthField(
                    label: 'CÓDIGO',
                    field: NexusTextField(
                      hint: '000000',
                      controller: _code,
                      validator: Validators.code,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.oneTimeCode],
                    ),
                  ),
                  AuthField(
                    label: 'CONTRASEÑA NUEVA',
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
                      onSubmitted: (_) => _reset(),
                    ),
                  ),
                  NexusPrimaryButton(
                    label: 'CAMBIAR CONTRASEÑA',
                    loading: action.isLoading,
                    onPressed: _reset,
                  ),
                  const SizedBox(height: 12),
                  AuthLink(
                    prefix: '¿No te llegó? ',
                    label: 'Reenviar código',
                    onTap: action.isLoading ? () {} : _requestCode,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
