import 'account_models.dart';

/// Rol y estado de la cuenta con sesión. Los errores llegan como `AppFailure`.
abstract class AccountRepository {
  Future<Account> getMyAccount();

  /// Registra la aceptación de las versiones vigentes y devuelve la cuenta
  /// actualizada.
  Future<Account> acceptDocuments(List<PendingDocument> documents);
}
