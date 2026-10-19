import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/validators.dart';
import '../../../routes.dart';
import '../../../widgets/nexus_widgets.dart';
import '../auth_providers.dart';
import 'auth_widgets.dart';

/// Inicio de sesión (HU-002). Se abre encima de la pantalla que lo pidió y
/// devuelve `true` al cerrar si el usuario quedó con sesión.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.reason});

  /// Por qué se pide la sesión, por ejemplo "para confirmar tu pedido".
  final String? reason;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref
        .read(signInControllerProvider.notifier)
        .submit(email: _email.text, password: _password.text);
    if (ok && mounted) _finish(true);
  }

  Future<void> _openAndFinishIfSignedIn(String route) async {
    final signedIn = await Navigator.of(context).pushNamed<bool>(route);
    if (signedIn == true && mounted) _finish(true);
  }

  void _finish(bool signedIn) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop(signedIn);
    } else {
      navigator.pushReplacementNamed(NexusRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(signInControllerProvider);

    return AuthScaffold(
      title: 'INICIA SESIÓN',
      subtitle: widget.reason == null
          ? 'Accede a tu cuenta para comprar y seguir tus pedidos.'
          : 'Inicia sesión ${widget.reason}.',
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (action.error case final error?) AuthErrorBanner(error),
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
                  hint: '••••••••',
                  obscure: true,
                  controller: _password,
                  validator: Validators.requiredPassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  autofillHints: const [AutofillHints.password],
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: AuthLink(
                  prefix: '',
                  label: '¿Olvidaste tu contraseña?',
                  onTap: () =>
                      _openAndFinishIfSignedIn(NexusRoutes.forgotPassword),
                ),
              ),
              const SizedBox(height: 8),
              NexusPrimaryButton(
                label: 'INGRESAR',
                loading: action.isLoading,
                onPressed: _submit,
              ),
              const SizedBox(height: 16),
              AuthLink(
                prefix: '¿No tienes cuenta? ',
                label: 'Crear cuenta',
                onTap: () => _openAndFinishIfSignedIn(NexusRoutes.signup),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
