import '../../account/domain/account_models.dart';
import 'admin_models.dart';

/// Estados a los que el administrador lleva una tienda.
const adminStoreStatuses = [StoreStatus.active, StoreStatus.suspended, StoreStatus.blocked, StoreStatus.deactivated];

/// Administración de tiendas. El backend exige el rol administrador en cada
/// llamada; crear cuentas va por la Edge Function `admin-providers`, que usa
/// la clave de servicio en el servidor. Los errores llegan como `AppFailure`.
abstract class AdminRepository {
  Future<List<AdminStore>> getStores({String search = ''});

  Future<AdminStore> getStore(String id);

  /// Habilita ([StoreStatus.active]), suspende, bloquea o desactiva. Salvo
  /// para habilitarla, el backend exige el [reason], que queda en el
  /// historial de la tienda.
  Future<AdminStore> setStoreStatus(String id, StoreStatus status, {String? reason});

  Future<AdminStore> updateStore(String id, StoreInput store, {bool confirmSimilarName = false});

  /// Crea la tienda y su cuenta con una contraseña temporal.
  Future<ProvisionResult> createStore(
    StoreInput store,
    NewAccountInput account, {
    bool confirmSimilarName = false,
  });

  /// Crea la cuenta de una tienda que ya existía sin cuenta.
  Future<ProvisionResult> createAccount(String storeId, NewAccountInput account);

  /// Regenera la contraseña temporal de la cuenta de la tienda.
  Future<ProvisionResult> resetPassword(String storeId);
}
