import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/nexus_theme.dart';
import '../../../widgets/nexus_error_state.dart';
import '../../../widgets/nexus_loading.dart';
import '../../../widgets/nexus_page.dart';
import '../../../widgets/nexus_widgets.dart';
import '../../auth/auth_providers.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../account_providers.dart';
import '../domain/account_models.dart';
import 'change_password_form.dart';

String roleLabel(AccountRole role) => switch (role) {
  AccountRole.customer => 'Cliente',
  AccountRole.provider => 'Tienda',
  AccountRole.admin => 'Administrador de NEXUS',
};

String storeStatusLabel(StoreStatus status) => switch (status) {
  StoreStatus.active => 'Habilitada',
  StoreStatus.suspended => 'Suspendida',
  StoreStatus.blocked => 'Bloqueada',
  StoreStatus.deactivated => 'Desactivada',
  StoreStatus.pending => 'Pendiente',
  StoreStatus.rejected => 'Rechazada',
};

/// Pestaña CUENTA de las tiendas y los administradores: datos de la cuenta,
/// la tienda, cambio de contraseña y cierre de sesión. Los clientes usan la
/// pestaña PERFIL, con direcciones.
class StaffAccountScreen extends ConsumerWidget {
  const StaffAccountScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthErrorBanner.messageFor(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountProvider);
    final email = ref.watch(currentUserProvider.select((user) => user?.email));

    return NexusPage(
      title: 'MI CUENTA',
      showCart: false,
      children: [
        account.when(
          loading: () => const NexusLoading(),
          error: (error, _) => NexusErrorState(
            message: 'No se pudo cargar tu cuenta.\n'
                '${AuthErrorBanner.messageFor(error)}',
            onRetry: () => ref.invalidate(accountProvider),
          ),
          data: (account) => account == null
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const NexusUnderlineTitle('CUENTA'),
                    const SizedBox(height: 4),
                    NexusCard(
                      child: Column(
                        children: [
                          NexusSpecRow('NOMBRE', account.fullName ?? '—'),
                          const Divider(color: NexusColors.border, height: 1),
                          NexusSpecRow('EMAIL', email ?? '—'),
                          const Divider(color: NexusColors.border, height: 1),
                          NexusSpecRow('ROL', roleLabel(account.role)),
                        ],
                      ),
                    ),
                    if (account.store case final store?) ...[
                      const SizedBox(height: 18),
                      const NexusUnderlineTitle('TIENDA'),
                      const SizedBox(height: 4),
                      NexusCard(
                        child: Column(
                          children: [
                            NexusSpecRow('NOMBRE VISIBLE', store.displayName),
                            const Divider(color: NexusColors.border, height: 1),
                            NexusSpecRow('ESTADO', storeStatusLabel(store.status)),
                          ],
                        ),
                      ),
                      if (store.status != StoreStatus.active)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Mientras tu tienda no esté habilitada, tus '
                            'publicaciones no se ven en el catálogo. '
                            'Comunícate con NEXUS.',
                            style: TextStyle(fontSize: 11.5, color: NexusColors.pink),
                          ),
                        ),
                      const SizedBox(height: 6),
                      const Text(
                        'El nombre visible lo cambia NEXUS: es el que ven los '
                        'clientes en cada tarjeta.',
                        style: TextStyle(fontSize: 11, color: NexusColors.textDim),
                      ),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 22),
        NexusOutlineButton(
          label: 'CAMBIAR CONTRASEÑA',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ChangePasswordScreen()),
          ),
        ),
        const SizedBox(height: 10),
        NexusOutlineButton(
          label: 'CERRAR SESIÓN',
          color: NexusColors.pink,
          borderColor: NexusColors.pink,
          onPressed: () => _signOut(context, ref),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
