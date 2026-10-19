import 'profile_models.dart';

/// Perfil y direcciones del usuario con sesión (HU-003). Cada usuario solo
/// accede a sus propios datos (RLS en el backend). Los errores llegan como
/// `AppFailure`.
abstract class ProfileRepository {
  Future<UserProfile> getProfile();

  Future<UserProfile> updateProfile({required String fullName, String? phone});

  /// La predeterminada primero; luego, de la más antigua a la más nueva.
  Future<List<Address>> listAddresses();

  Future<void> createAddress(AddressInput input);

  Future<void> updateAddress(String id, AddressInput input);

  /// Si era la predeterminada, pasa a serlo la más reciente que quede.
  Future<void> deleteAddress(String id);
}
