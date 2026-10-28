import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/nexus_error_state.dart';
import '../../../widgets/nexus_loading.dart';
import '../../../widgets/nexus_widgets.dart';
import '../../auth/auth_providers.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../account_providers.dart';
import '../domain/account_models.dart';
import 'change_password_form.dart';

/// Primer ingreso de una cuenta de tienda (la creó un administrador): cambiar
/// la contraseña temporal y aceptar los documentos vigentes. Hasta entonces el
/// backend no la deja publicar; esta pantalla solo guía los dos pasos.
class StoreSetupScreen extends ConsumerWidget {
  const StoreSetupScreen({super.key, required this.account});

  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeName = account.store?.displayName ?? 'tu tienda';

    return AuthScaffold(
      title: 'ACTIVA TU TIENDA',
      subtitle: account.mustChangePassword
          ? 'Paso 1 de 2 · $storeName: cambia la contraseña temporal que te '
                'entregó NEXUS.'
          : 'Paso 2 de 2 · $storeName: acepta los documentos vigentes para '
                'publicar tus productos.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (account.mustChangePassword)
            const ChangePasswordForm(submitLabel: 'GUARDAR Y CONTINUAR')
          else
            _AcceptDocuments(pending: account.pendingDocuments),
          const SizedBox(height: 16),
          AuthLink(
            prefix: '¿No es tu cuenta? ',
            label: 'Cerrar sesión',
            onTap: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
    );
  }
}

class _AcceptDocuments extends ConsumerStatefulWidget {
  const _AcceptDocuments({required this.pending});

  final List<PendingDocument> pending;

  @override
  ConsumerState<_AcceptDocuments> createState() => _AcceptDocumentsState();
}

class _AcceptDocumentsState extends ConsumerState<_AcceptDocuments> {
  var _accepted = false;
  var _showError = false;

  Future<void> _submit() async {
    if (!_accepted) {
      setState(() => _showError = true);
      return;
    }
    await ref
        .read(acceptDocumentsControllerProvider.notifier)
        .submit(widget.pending);
  }

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(acceptDocumentsControllerProvider);
    final documents = ref.watch(legalDocumentsProvider);
    final pendingCodes = {for (final d in widget.pending) d.code};

    return documents.when(
      loading: () => const NexusLoading(),
      error: (error, _) => NexusErrorState(
        message: 'No se pudieron cargar los documentos.\n'
            '${AuthErrorBanner.messageFor(error)}',
        onRetry: () => ref.invalidate(legalDocumentsProvider),
      ),
      data: (documents) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (action.error case final error?) AuthErrorBanner(error),
          LegalConsentCheckbox(
            documents: [
              for (final document in documents)
                if (pendingCodes.contains(document.code)) document,
            ],
            value: _accepted,
            showError: _showError && !_accepted,
            errorText: 'Debes aceptar los documentos para publicar en NEXUS.',
            onChanged: (value) => setState(() => _accepted = value),
          ),
          const SizedBox(height: 16),
          NexusPrimaryButton(
            label: 'ACEPTAR Y CONTINUAR',
            loading: action.isLoading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
