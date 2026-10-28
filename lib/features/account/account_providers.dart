import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/supabase_providers.dart';
import '../auth/auth_providers.dart';
import '../auth/data/mock_auth_repository.dart';
import 'data/mock_account_repository.dart';
import 'data/mock_directory.dart';
import 'data/supabase_account_repository.dart';
import 'domain/account_models.dart';
import 'domain/account_repository.dart';

/// Roles y tiendas en memoria de los mocks. Se renueva con el repositorio de
/// cuentas (cada prueba tiene el suyo).
final mockDirectoryProvider = Provider<MockDirectory>((ref) {
  ref.watch(authRepositoryProvider);
  return MockDirectory();
});

/// Con el mock de cuentas usa el mock; si no, las RPC de Supabase.
final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  if (auth is MockAuthRepository) {
    return MockAccountRepository(
      auth,
      ref.watch(mockDirectoryProvider),
      latency: auth.latency,
    );
  }
  return SupabaseAccountRepository.fromClient(ref.watch(supabaseClientProvider));
});

/// Cuenta con sesión, o `null` sin sesión. Se recalcula al cambiar de usuario.
final accountProvider = FutureProvider<Account?>((ref) async {
  final userId = ref.watch(currentUserProvider.select((user) => user?.id));
  if (userId == null) return null;
  return ref.watch(accountRepositoryProvider).getMyAccount();
});

/// Si la cuenta compra. Sin sesión, mientras carga o si no se pudo leer la
/// cuenta, la interfaz es la del cliente: el backend igual rechaza a quien no
/// lo es (CUSTOMER_ONLY).
final canBuyProvider = Provider<bool>(
  (ref) => ref.watch(accountProvider).value?.canBuy ?? true,
);

/// Aceptación de los documentos vigentes en el primer ingreso de una tienda.
final acceptDocumentsControllerProvider =
    AsyncNotifierProvider.autoDispose<AcceptDocumentsController, void>(
      AcceptDocumentsController.new,
    );

class AcceptDocumentsController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<bool> submit(List<PendingDocument> documents) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(accountRepositoryProvider).acceptDocuments(documents);
      ref.invalidate(accountProvider);
    });
    return !state.hasError;
  }
}

/// Cambio de contraseña: el obligatorio del primer ingreso y el voluntario.
final changePasswordControllerProvider =
    AsyncNotifierProvider.autoDispose<ChangePasswordController, void>(
      ChangePasswordController.new,
    );

class ChangePasswordController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<bool> submit(String newPassword) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).changePassword(newPassword);
      // El backend quitó la marca de contraseña temporal.
      ref.invalidate(accountProvider);
    });
    return !state.hasError;
  }
}
