import 'auth_models.dart';

/// Autenticación del cliente (HU-001, HU-002). Los errores llegan como
/// `AppFailure` (`core/errors/app_failure.dart`).
abstract class AuthRepository {
  AuthUser? get currentUser;

  /// Emite el usuario actual al suscribirse y después cada cambio de sesión.
  Stream<AuthUser?> authStateChanges();

  Future<void> signIn({required String email, required String password});

  /// [acceptedDocuments] son las versiones vigentes que el usuario aceptó; el
  /// backend rechaza el registro si falta alguna (RN-033).
  Future<SignUpResult> signUp({
    required String fullName,
    required String email,
    required String password,
    required List<LegalDocument> acceptedDocuments,
  });

  Future<void> signOut();

  /// Envía al correo un código de 6 dígitos para restablecer la contraseña.
  Future<void> requestPasswordReset(String email);

  /// Valida el código, cambia la contraseña y deja la sesión iniciada.
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  });

  /// Cambia la contraseña del usuario con sesión. En las cuentas de tienda,
  /// cambiar la contraseña temporal es el primer paso del primer ingreso.
  Future<void> changePassword(String newPassword);

  Future<List<LegalDocument>> getCurrentLegalDocuments();
}
