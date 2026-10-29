import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/account/account_providers.dart';
import '../../features/account/domain/account_models.dart';
import '../../features/account/presentation/store_setup_screen.dart';
import '../../features/admin/presentation/admin_shell.dart';
import '../../features/auth/auth_providers.dart';
import '../../features/auth/presentation/auth_widgets.dart';
import '../../features/vendor/presentation/vendor_shell.dart';
import '../../theme/nexus_theme.dart';
import '../../widgets/nexus_error_state.dart';
import '../../widgets/nexus_loading.dart';
import 'main_shell.dart';

enum _Home { customer, storeSetup, store, admin }

/// Pantalla inicial según el rol de la cuenta (API_CONTRATO, parte 7).
///
/// - Sin sesión o cliente: el shell de siempre (`MainShell`).
/// - Tienda: su primer ingreso (contraseña y documentos) y después
///   el panel de la tienda (`VendorShell`, con menú lateral).
/// - Administrador: la consola de NEXUS (`AdminShell`, con menú lateral).
///
/// Es solo navegación: el backend valida el rol en cada función. Mientras la
/// cuenta carga se conserva la pantalla anterior (así un cliente que inicia
/// sesión no pierde la pestaña en la que estaba) y nunca se muestra por
/// defecto la de un rol con más permisos.
class RoleHome extends ConsumerStatefulWidget {
  const RoleHome({super.key});

  @override
  ConsumerState<RoleHome> createState() => _RoleHomeState();
}

class _RoleHomeState extends ConsumerState<RoleHome> {
  _Home? _last;
  Account? _lastAccount;

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(currentUserProvider.select((user) => user != null));
    if (!signedIn) return _show(_Home.customer);

    return ref.watch(accountProvider).when(
      data: (account) {
        if (account == null) return _show(_Home.customer);
        _lastAccount = account;
        return _show(switch (account.role) {
          AccountRole.customer => _Home.customer,
          AccountRole.provider =>
            account.needsStoreSetup ? _Home.storeSetup : _Home.store,
          AccountRole.admin => _Home.admin,
        });
      },
      loading: () => _last == null ? const _Loading() : _show(_last!),
      error: (error, _) => _last == null
          ? _AccountError(error: error)
          : _show(_last!),
    );
  }

  Widget _show(_Home home) {
    _last = home;
    return switch (home) {
      _Home.customer => const MainShell(),
      _Home.store => const VendorShell(),
      _Home.admin => const AdminShell(),
      _Home.storeSetup => _lastAccount == null
          ? const _Loading()
          : StoreSetupScreen(account: _lastAccount!),
    };
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(backgroundColor: NexusColors.bg, body: Center(child: NexusLoading()));
}

class _AccountError extends ConsumerWidget {
  const _AccountError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: NexusColors.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                NexusErrorState(
                  message: 'No se pudo cargar tu cuenta.\n'
                      '${AuthErrorBanner.messageFor(error)}',
                  onRetry: () => ref.invalidate(accountProvider),
                ),
                TextButton(
                  onPressed: () => ref.read(authRepositoryProvider).signOut(),
                  child: const Text('Cerrar sesión'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
