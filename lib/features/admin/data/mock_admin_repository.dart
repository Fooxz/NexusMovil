import 'dart:math';

import '../../../core/errors/app_failure.dart';
import '../../account/data/mock_directory.dart';
import '../../account/domain/account_models.dart';
import '../../auth/data/mock_auth_repository.dart';
import '../domain/admin_models.dart';
import '../domain/admin_repository.dart';

/// Administración de tiendas en memoria. Aplica las reglas de las RPC
/// `admin_*` y de la Edge Function: solo administradores, NIT único, aviso de
/// nombre visible parecido y cuentas nuevas con contraseña temporal. El
/// estado de las tiendas no cambia el catálogo del mock (son datos aparte).
class MockAdminRepository implements AdminRepository {
  MockAdminRepository(
    this._auth,
    this._directory, {
    this.latency = const Duration(milliseconds: 200),
  });

  final MockAuthRepository _auth;
  final MockDirectory _directory;
  final Duration latency;
  var _nextId = 1;

  static final _random = Random.secure();
  static const _alphabet = 'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#\$%*-_+=?';

  Future<void> _simulateLatency() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  void _requireAdmin() {
    final user = _auth.currentUser;
    if (user == null) throw const UnauthorizedFailure();
    if (_directory.roles[user.id] != AccountRole.admin) throw const ForbiddenFailure();
  }

  /// Con al menos una letra y un número, como exige Supabase Auth.
  static String _temporaryPassword() {
    while (true) {
      final password = List.generate(20, (_) => _alphabet[_random.nextInt(_alphabet.length)]).join();
      if (password.contains(RegExp('[A-Za-z]')) && password.contains(RegExp('[0-9]'))) return password;
    }
  }

  AdminStore _toAdmin(MockStore store) => AdminStore(
    id: store.id,
    legalName: store.legalName,
    displayName: store.displayName,
    taxId: store.taxId,
    contactEmail: store.contactEmail,
    status: store.status,
    verificationNote: store.verificationNote,
    accountEmail: store.userId == null ? null : _auth.emailOf(store.userId!),
  );

  MockStore _find(String id) => _directory.stores[id] ?? (throw const NotFoundFailure());

  static String _key(String value) => value.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

  void _validate(StoreInput store, String? currentId, {required bool confirmSimilarName}) {
    if (store.legalName.trim().length < 2) {
      throw const FieldValidationFailure(field: 'legalName', message: 'La razón social debe tener de 2 a 160 caracteres');
    }
    if (store.displayName.trim().length < 2) {
      throw const FieldValidationFailure(field: 'displayName', message: 'El nombre visible debe tener de 2 a 60 caracteres');
    }
    if (!RegExp(r'^[0-9]{6,12}(-[0-9])?$').hasMatch(store.taxId.trim())) {
      throw const FieldValidationFailure(field: 'taxId', message: 'El NIT debe tener el formato 900123456-7');
    }
    final others = _directory.stores.values.where((s) => s.id != currentId);
    if (others.any((s) => s.taxId == store.taxId.trim())) throw const TaxIdTakenFailure();
    if (!confirmSimilarName) {
      for (final other in others) {
        if (_key(other.displayName) == _key(store.displayName)) {
          throw SimilarStoreNameFailure(other.displayName);
        }
      }
    }
  }

  MockStore _apply(MockStore target, StoreInput store) => target
    ..legalName = store.legalName.trim()
    ..displayName = store.displayName.trim()
    ..taxId = store.taxId.trim()
    ..contactEmail = store.contactEmail.trim().toLowerCase()
    ..verificationNote = store.verificationNote?.trim();

  /// Cuenta de tienda nueva: contraseña temporal y primer ingreso pendiente.
  ({String userId, String password}) _newAccount(NewAccountInput account) {
    final password = _temporaryPassword();
    final userId = _auth.createAccount(email: account.email, fullName: account.fullName, password: password);
    _directory.roles[userId] = AccountRole.provider;
    _directory.provisioned.add(userId);
    return (userId: userId, password: password);
  }

  @override
  Future<List<AdminStore>> getStores({String search = ''}) async {
    await _simulateLatency();
    _requireAdmin();
    final query = search.trim().toLowerCase();
    return [
      for (final store in _directory.stores.values)
        if (query.isEmpty ||
            store.displayName.toLowerCase().contains(query) ||
            store.legalName.toLowerCase().contains(query) ||
            store.taxId.contains(query))
          _toAdmin(store),
    ]..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
  }

  @override
  Future<AdminStore> getStore(String id) async {
    await _simulateLatency();
    _requireAdmin();
    return _toAdmin(_find(id));
  }

  @override
  Future<AdminStore> setStoreStatus(String id, StoreStatus status) async {
    await _simulateLatency();
    _requireAdmin();
    if (status != StoreStatus.active && status != StoreStatus.suspended) throw const ValidationFailure();
    return _toAdmin(_find(id)..status = status);
  }

  @override
  Future<AdminStore> updateStore(String id, StoreInput store, {bool confirmSimilarName = false}) async {
    await _simulateLatency();
    _requireAdmin();
    final target = _find(id);
    _validate(store, id, confirmSimilarName: confirmSimilarName);
    return _toAdmin(_apply(target, store));
  }

  @override
  Future<ProvisionResult> createStore(
    StoreInput store,
    NewAccountInput account, {
    bool confirmSimilarName = false,
  }) async {
    await _simulateLatency();
    _requireAdmin();
    _validate(store, null, confirmSimilarName: confirmSimilarName);
    final created = _newAccount(account);
    final id = 'mock-store-${_nextId++}';
    _directory.stores[id] = _apply(
      MockStore(id: id, legalName: '', displayName: '', taxId: '', contactEmail: '', userId: created.userId),
      store,
    );
    return ProvisionResult(store: _toAdmin(_directory.stores[id]!), temporaryPassword: created.password);
  }

  @override
  Future<ProvisionResult> createAccount(String storeId, NewAccountInput account) async {
    await _simulateLatency();
    _requireAdmin();
    final store = _find(storeId);
    if (store.userId != null) throw const StoreHasAccountFailure();
    final created = _newAccount(account);
    store.userId = created.userId;
    return ProvisionResult(store: _toAdmin(store), temporaryPassword: created.password);
  }

  @override
  Future<ProvisionResult> resetPassword(String storeId) async {
    await _simulateLatency();
    _requireAdmin();
    final store = _find(storeId);
    final userId = store.userId ?? (throw const NotFoundFailure());
    final password = _temporaryPassword();
    _auth.setPassword(userId, password);
    _directory.provisioned.add(userId);
    return ProvisionResult(store: _toAdmin(store), temporaryPassword: password);
  }
}
