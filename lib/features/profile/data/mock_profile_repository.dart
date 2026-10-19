import '../../../core/errors/app_failure.dart';
import '../../../core/utils/validators.dart';
import '../../auth/data/mock_auth_repository.dart';
import '../domain/profile_models.dart';
import '../domain/profile_repository.dart';

/// Perfil y direcciones en memoria, por usuario del [MockAuthRepository].
/// Reproduce las reglas del backend: una sola dirección predeterminada y la
/// primera lo es siempre.
class MockProfileRepository implements ProfileRepository {
  MockProfileRepository(
    this._auth, {
    this.latency = const Duration(milliseconds: 200),
  });

  final MockAuthRepository _auth;
  final Duration latency;
  final _phones = <String, String?>{};
  final _names = <String, String>{};
  final _addresses = <String, List<Address>>{};
  var _nextId = 1;

  /// Sin latencia no espera: dentro de `testWidgets` un `Future.delayed`
  /// solo avanza con `pump`, y las pruebas preparan datos sin bombear.
  Future<void> _simulateLatency() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  String get _userId =>
      _auth.currentUser?.id ?? (throw const UnauthorizedFailure());

  @override
  Future<UserProfile> getProfile() async {
    await _simulateLatency();
    final user = _auth.currentUser ?? (throw const UnauthorizedFailure());
    return UserProfile(
      id: user.id,
      email: user.email,
      fullName: _names[user.id] ?? _auth.fullNameOf(user.id) ?? '',
      phone: _phones[user.id],
    );
  }

  @override
  Future<UserProfile> updateProfile({
    required String fullName,
    String? phone,
  }) async {
    await _simulateLatency();
    final userId = _userId;
    final normalized = Validators.normalizePhone(phone ?? '');
    _names[userId] = fullName.trim();
    _phones[userId] = normalized.isEmpty ? null : normalized;
    return getProfile();
  }

  @override
  Future<List<Address>> listAddresses() async {
    await _simulateLatency();
    final addresses = _addresses[_userId] ?? const <Address>[];
    return [
      ...addresses.where((address) => address.isDefault),
      ...addresses.where((address) => !address.isDefault),
    ];
  }

  @override
  Future<void> createAddress(AddressInput input) async {
    await _simulateLatency();
    final list = _addresses.putIfAbsent(_userId, () => []);
    final makeDefault = input.isDefault || list.isEmpty;
    if (makeDefault) _clearDefault(list);
    list.add(_build('mock-address-${_nextId++}', input, makeDefault));
  }

  @override
  Future<void> updateAddress(String id, AddressInput input) async {
    await _simulateLatency();
    final list = _addresses[_userId] ?? [];
    final index = list.indexWhere((address) => address.id == id);
    if (index < 0) throw const NotFoundFailure();
    final makeDefault = input.isDefault || list[index].isDefault;
    if (input.isDefault) _clearDefault(list);
    list[index] = _build(id, input, makeDefault);
  }

  @override
  Future<void> deleteAddress(String id) async {
    await _simulateLatency();
    final list = _addresses[_userId] ?? [];
    final index = list.indexWhere((address) => address.id == id);
    if (index < 0) return;
    final removed = list.removeAt(index);
    if (removed.isDefault && list.isNotEmpty) {
      final newest = list.removeLast();
      list.add(_build(newest.id, newest.toInput(), true));
    }
  }

  static void _clearDefault(List<Address> list) {
    for (var index = 0; index < list.length; index++) {
      if (list[index].isDefault) {
        list[index] = _build(list[index].id, list[index].toInput(), false);
      }
    }
  }

  static Address _build(String id, AddressInput input, bool isDefault) {
    final details = input.details?.trim() ?? '';
    return Address(
      id: id,
      label: input.label.trim(),
      recipientName: input.recipientName.trim(),
      phone: Validators.normalizePhone(input.phone),
      department: input.department,
      city: input.city.trim(),
      addressLine: input.addressLine.trim(),
      details: details.isEmpty ? null : details,
      isDefault: isDefault,
    );
  }
}
