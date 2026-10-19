import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../../core/errors/app_failure.dart';
import '../../../core/utils/validators.dart';
import '../domain/profile_models.dart';
import '../domain/profile_repository.dart';

/// Perfil y direcciones en las tablas `profiles` y `addresses`. RLS limita
/// cada consulta al usuario de la sesión (docs/MODELO_DATOS.md, "Cuentas").
class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  static const _addressColumns =
      'id, label, recipient_name, phone, department, city, address_line, details, is_default';

  User get _user =>
      _client.auth.currentUser ?? (throw const UnauthorizedFailure());

  @override
  Future<UserProfile> getProfile() async {
    final user = _user;
    final row = await _guard(
      () => _client
          .from('profiles')
          .select('full_name, phone')
          .eq('id', user.id)
          .single(),
    );
    return _profileFromRow(user, row);
  }

  @override
  Future<UserProfile> updateProfile({
    required String fullName,
    String? phone,
  }) async {
    final user = _user;
    final normalizedPhone = Validators.normalizePhone(phone ?? '');
    final row = await _guard(
      () => _client
          .from('profiles')
          .update({
            'full_name': fullName.trim(),
            'phone': normalizedPhone.isEmpty ? null : normalizedPhone,
          })
          .eq('id', user.id)
          .select('full_name, phone')
          .single(),
    );
    return _profileFromRow(user, row);
  }

  @override
  Future<List<Address>> listAddresses() async {
    _user;
    final rows = await _guard(
      () => _client
          .from('addresses')
          .select(_addressColumns)
          .order('is_default', ascending: false)
          .order('created_at'),
    );
    return [for (final row in rows) addressFromRow(row)];
  }

  @override
  Future<void> createAddress(AddressInput input) async {
    _user;
    await _guard(() => _client.from('addresses').insert(addressToRow(input)));
  }

  @override
  Future<void> updateAddress(String id, AddressInput input) async {
    _user;
    await _guard(
      () => _client.from('addresses').update(addressToRow(input)).eq('id', id),
    );
  }

  @override
  Future<void> deleteAddress(String id) async {
    _user;
    await _guard(() => _client.from('addresses').delete().eq('id', id));
  }

  static UserProfile _profileFromRow(User user, Map<String, dynamic> row) =>
      UserProfile(
        id: user.id,
        email: user.email ?? '',
        fullName: row['full_name'] as String,
        phone: row['phone'] as String?,
      );

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AppFailure {
      rethrow;
    } on PostgrestException catch (error) {
      // 23514: una restricción CHECK de la tabla (datos inválidos).
      // PGRST116: `.single()` sin filas (perfil inexistente).
      throw switch (error.code) {
        '23514' || '23502' => const ValidationFailure(),
        'PGRST116' => const NotFoundFailure(),
        '42501' => const UnauthorizedFailure(),
        _ => const UnexpectedFailure(),
      };
    } on Exception {
      throw const NetworkFailure();
    }
  }
}

Address addressFromRow(Map<String, dynamic> row) => Address(
  id: row['id'] as String,
  label: row['label'] as String,
  recipientName: row['recipient_name'] as String,
  phone: row['phone'] as String,
  department: row['department'] as String,
  city: row['city'] as String,
  addressLine: row['address_line'] as String,
  details: row['details'] as String?,
  isDefault: row['is_default'] as bool,
);

/// Columnas que el cliente envía. `user_id` lo pone el backend
/// (`default auth.uid()`) y RLS exige que sea el de la sesión.
Map<String, Object?> addressToRow(AddressInput input) {
  final details = input.details?.trim() ?? '';
  return {
    'label': input.label.trim(),
    'recipient_name': input.recipientName.trim(),
    'phone': Validators.normalizePhone(input.phone),
    'department': input.department,
    'city': input.city.trim(),
    'address_line': input.addressLine.trim(),
    'details': details.isEmpty ? null : details,
    // Solo se envía `true`: desmarcar una predeterminada dejaría al usuario
    // sin ninguna. Para cambiarla se marca otra.
    if (input.isDefault) 'is_default': true,
  };
}
