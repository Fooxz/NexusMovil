import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/supabase_providers.dart';
import '../account/account_providers.dart';
import '../auth/auth_providers.dart';
import '../auth/data/mock_auth_repository.dart';
import 'data/mock_admin_repository.dart';
import 'data/supabase_admin_repository.dart';
import 'domain/admin_models.dart';
import 'domain/admin_repository.dart';

/// Con el mock de cuentas usa el mock; si no, Supabase.
final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  if (auth is MockAuthRepository) {
    return MockAdminRepository(auth, ref.watch(mockDirectoryProvider), latency: auth.latency);
  }
  return SupabaseAdminRepository.fromClient(ref.watch(supabaseClientProvider));
});

/// Tiendas, filtradas por la búsqueda.
final adminStoresProvider = FutureProvider.autoDispose.family<List<AdminStore>, String>(
  (ref, search) => ref.watch(adminRepositoryProvider).getStores(search: search),
);

final adminStoreProvider = FutureProvider.autoDispose.family<AdminStore, String>(
  (ref, id) => ref.watch(adminRepositoryProvider).getStore(id),
);

/// Acciones del administrador. Al terminar refresca la lista y el detalle.
/// Las pantallas leen el error del estado (por ejemplo,
/// `SimilarStoreNameFailure`).
final adminActionControllerProvider = AsyncNotifierProvider.autoDispose<AdminActionController, void>(
  AdminActionController.new,
);

class AdminActionController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Devuelve el resultado, o `null` si falló.
  Future<T?> run<T>(Future<T> Function(AdminRepository) action, {required String Function(T) storeId}) async {
    state = const AsyncLoading();
    T? result;
    state = await AsyncValue.guard(() async {
      result = await action(ref.read(adminRepositoryProvider));
      ref
        ..invalidate(adminStoresProvider)
        ..invalidate(adminStoreProvider(storeId(result as T)));
    });
    return state.hasError ? null : result;
  }

  void clearError() => state = const AsyncData(null);
}
