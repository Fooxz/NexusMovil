import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/nexus_theme.dart';
import '../../../widgets/nexus_error_state.dart';
import '../../../widgets/nexus_loading.dart';
import '../../../widgets/nexus_page.dart';
import '../../../widgets/nexus_widgets.dart';
import '../../account/domain/account_models.dart';
import '../../account/presentation/staff_account_screen.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../admin_providers.dart';
import '../domain/admin_models.dart';
import 'admin_store_form_screen.dart';
import 'temporary_password_dialog.dart';

/// Detalle de una tienda: habilitar o suspender, editar sus datos, crear su
/// cuenta o regenerar la contraseña temporal.
class AdminStoreScreen extends ConsumerWidget {
  const AdminStoreScreen({super.key, required this.storeId});

  final String storeId;

  Future<bool> _confirm(BuildContext context, String title, String message, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(action)),
          ],
        ),
      ) ==
      true;

  void _showError(BuildContext context, WidgetRef ref) {
    final error = ref.read(adminActionControllerProvider).error;
    if (error == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(AuthErrorBanner.messageFor(error))));
  }

  Future<void> _toggleStatus(BuildContext context, WidgetRef ref, AdminStore store) async {
    final suspend = store.status == StoreStatus.active;
    final confirmed = await _confirm(
      context,
      suspend ? 'Suspender tienda' : 'Habilitar tienda',
      suspend
          ? 'Las ofertas de ${store.displayName} dejan de verse en el catálogo y la tienda no puede publicar.'
          : '${store.displayName} podrá publicar y sus ofertas publicadas volverán al catálogo.',
      suspend ? 'Suspender' : 'Habilitar',
    );
    if (!confirmed || !context.mounted) return;
    final result = await ref.read(adminActionControllerProvider.notifier).run(
      (repository) => repository.setStoreStatus(store.id, suspend ? StoreStatus.suspended : StoreStatus.active),
      storeId: (store) => store.id,
    );
    if (context.mounted && result == null) _showError(context, ref);
  }

  Future<void> _resetPassword(BuildContext context, WidgetRef ref, AdminStore store) async {
    final confirmed = await _confirm(
      context,
      'Regenerar contraseña',
      'La contraseña actual de ${store.accountEmail} deja de servir. La tienda debe cambiar la nueva en su próximo ingreso.',
      'Regenerar',
    );
    if (!confirmed || !context.mounted) return;
    final result = await ref.read(adminActionControllerProvider.notifier).run(
      (repository) => repository.resetPassword(store.id),
      storeId: (result) => result.store.id,
    );
    if (!context.mounted) return;
    if (result == null) {
      _showError(context, ref);
      return;
    }
    await showTemporaryPassword(
      context,
      storeName: result.store.displayName,
      accountEmail: result.store.accountEmail ?? '',
      password: result.temporaryPassword,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(adminStoreProvider(storeId));
    final action = ref.watch(adminActionControllerProvider);

    return NexusPage(
      title: 'TIENDA',
      showBack: true,
      showCart: false,
      children: [
        store.when(
          loading: () => const NexusLoading(),
          error: (error, _) => NexusErrorState(
            message: 'No se pudo cargar la tienda.\n${AuthErrorBanner.messageFor(error)}',
            onRetry: () => ref.invalidate(adminStoreProvider(storeId)),
          ),
          data: (store) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                store.displayName,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              const SizedBox(height: 10),
              NexusCard(
                child: Column(
                  children: [
                    NexusSpecRow('RAZÓN SOCIAL', store.legalName),
                    const Divider(color: NexusColors.border, height: 1),
                    NexusSpecRow('NIT', store.taxId),
                    const Divider(color: NexusColors.border, height: 1),
                    NexusSpecRow('CONTACTO', store.contactEmail),
                    const Divider(color: NexusColors.border, height: 1),
                    NexusSpecRow(
                      'ESTADO',
                      storeStatusLabel(store.status),
                      valueColor: store.status == StoreStatus.active ? NexusColors.green : NexusColors.pink,
                    ),
                    const Divider(color: NexusColors.border, height: 1),
                    NexusSpecRow('CUENTA', store.accountEmail ?? 'Sin cuenta'),
                    const Divider(color: NexusColors.border, height: 1),
                    NexusSpecRow('OFERTAS PUBLICADAS', '${store.publishedOffers}'),
                    if (store.verificationNote case final note?) ...[
                      const Divider(color: NexusColors.border, height: 1),
                      NexusSpecRow('VERIFICACIÓN', note),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              NexusPrimaryButton(
                label: store.status == StoreStatus.active ? 'SUSPENDER TIENDA' : 'HABILITAR TIENDA',
                color: store.status == StoreStatus.active ? NexusColors.pink : NexusColors.cyan,
                foregroundColor: store.status == StoreStatus.active ? Colors.white : NexusColors.onCyan,
                loading: action.isLoading,
                onPressed: () => _toggleStatus(context, ref, store),
              ),
              const SizedBox(height: 10),
              NexusOutlineButton(
                label: 'EDITAR DATOS',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => AdminStoreFormScreen.edit(current: store)),
                ),
              ),
              const SizedBox(height: 10),
              if (store.hasAccount)
                NexusOutlineButton(
                  label: 'REGENERAR CONTRASEÑA TEMPORAL',
                  onPressed: action.isLoading ? null : () => _resetPassword(context, ref, store),
                )
              else
                NexusOutlineButton(
                  label: 'CREAR CUENTA PARA LA TIENDA',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => AdminAccountFormScreen(store: store)),
                  ),
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }
}
