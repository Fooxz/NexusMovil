import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/supabase_providers.dart';
import '../auth/auth_providers.dart';
import '../auth/data/mock_auth_repository.dart';
import 'data/mock_profile_repository.dart';
import 'data/supabase_profile_repository.dart';
import 'domain/profile_models.dart';
import 'domain/profile_repository.dart';

/// Va en pareja con la autenticación: con el mock de cuentas usa el mock de
/// perfil; con Supabase Auth, las tablas de Supabase.
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  if (auth is MockAuthRepository) return MockProfileRepository(auth);
  return SupabaseProfileRepository(ref.watch(supabaseClientProvider));
});

/// Perfil del usuario con sesión; `null` sin sesión. Se recarga al cambiar
/// de usuario.
final profileProvider = FutureProvider.autoDispose<UserProfile?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return ref.watch(profileRepositoryProvider).getProfile();
});

/// Direcciones del usuario con sesión; vacía sin sesión.
final addressesProvider = FutureProvider.autoDispose<List<Address>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.watch(profileRepositoryProvider).listAddresses();
});

// --- Acciones de formulario ---------------------------------------------

final profileFormControllerProvider =
    AsyncNotifierProvider.autoDispose<ProfileFormController, void>(
      ProfileFormController.new,
    );

class ProfileFormController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<bool> save({required String fullName, String? phone}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(profileRepositoryProvider)
          .updateProfile(fullName: fullName, phone: phone),
    );
    if (state.hasError) return false;
    ref.invalidate(profileProvider);
    return true;
  }
}

final addressFormControllerProvider =
    AsyncNotifierProvider.autoDispose<AddressFormController, void>(
      AddressFormController.new,
    );

/// Acciones de la lista (eliminar, marcar predeterminada). Va aparte del
/// formulario para que un error de la lista no aparezca en el formulario.
final addressListActionsProvider =
    AsyncNotifierProvider.autoDispose<AddressFormController, void>(
      AddressFormController.new,
    );

class AddressFormController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Crea la dirección si [id] es `null`; si no, la actualiza.
  Future<bool> save(AddressInput input, {String? id}) => _mutate(
    () => id == null
        ? ref.read(profileRepositoryProvider).createAddress(input)
        : ref.read(profileRepositoryProvider).updateAddress(id, input),
  );

  Future<bool> delete(String id) =>
      _mutate(() => ref.read(profileRepositoryProvider).deleteAddress(id));

  Future<bool> makeDefault(Address address) => _mutate(
    () => ref
        .read(profileRepositoryProvider)
        .updateAddress(address.id, _withDefault(address)),
  );

  Future<bool> _mutate(Future<void> Function() action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(action);
    if (state.hasError) return false;
    ref.invalidate(addressesProvider);
    return true;
  }

  static AddressInput _withDefault(Address address) {
    final input = address.toInput();
    return AddressInput(
      label: input.label,
      recipientName: input.recipientName,
      phone: input.phone,
      department: input.department,
      city: input.city,
      addressLine: input.addressLine,
      details: input.details,
      isDefault: true,
    );
  }
}
