import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../../core/errors/app_failure.dart';
import '../domain/auth_models.dart';
import '../domain/auth_repository.dart';

/// Autenticación con Supabase Auth. El perfil y los consentimientos los crea
/// el trigger `private.handle_new_user` a partir de los metadatos del registro.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  @override
  AuthUser? get currentUser => _toAuthUser(_auth.currentUser);

  @override
  Stream<AuthUser?> authStateChanges() => _auth.onAuthStateChange
      .map((state) => _toAuthUser(state.session?.user))
      .distinct();

  @override
  Future<void> signIn({required String email, required String password}) =>
      _guard(
        () => _auth.signInWithPassword(email: email.trim(), password: password),
      );

  @override
  Future<SignUpResult> signUp({
    required String fullName,
    required String email,
    required String password,
    required List<LegalDocument> acceptedDocuments,
  }) async {
    final response = await _guard(
      () => _auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'full_name': fullName.trim(),
          'accepted_documents': [
            for (final document in acceptedDocuments)
              {'code': document.code, 'version': document.version},
          ],
        },
      ),
    );
    return response.session == null
        ? SignUpResult.confirmationRequired
        : SignUpResult.signedIn;
  }

  @override
  Future<void> signOut() => _guard(() => _auth.signOut());

  @override
  Future<void> requestPasswordReset(String email) =>
      _guard(() => _auth.resetPasswordForEmail(email.trim()));

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _guard(
      () => _auth.verifyOTP(
        email: email.trim(),
        token: code.trim(),
        type: OtpType.recovery,
      ),
    );
    await _guard(() => _auth.updateUser(UserAttributes(password: newPassword)));
  }

  @override
  Future<void> changePassword(String newPassword) =>
      _guard(() => _auth.updateUser(UserAttributes(password: newPassword)));

  @override
  Future<List<LegalDocument>> getCurrentLegalDocuments() async {
    final rows = await _guard(
      () => _client
          .from('legal_documents')
          .select('code, version, title, content')
          .order('code'),
    );
    return [
      for (final row in rows)
        LegalDocument(
          code: row['code'] as String,
          version: row['version'] as String,
          title: row['title'] as String,
          content: row['content'] as String,
        ),
    ];
  }

  static AuthUser? _toAuthUser(User? user) => user == null
      ? null
      : AuthUser(id: user.id, email: user.email ?? '');

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      throw mapAuthError(error);
    }
  }
}

/// Traduce los errores de Supabase Auth y de red a `AppFailure`.
AppFailure mapAuthError(Object error) {
  if (error is AppFailure) return error;
  if (error is AuthException) {
    // Si el trigger de alta (private.handle_new_user) rechaza el registro,
    // GoTrue responde 500 "Database error saving new user" sin el detalle.
    // La app valida el nombre antes de enviar, así que la causa es el
    // consentimiento: por ejemplo, se publicó una versión nueva de los
    // documentos mientras el usuario llenaba el formulario.
    if (error.message.contains('CONSENT_REQUIRED') ||
        error.message.contains('Database error saving new user')) {
      return const ConsentRequiredFailure();
    }
    return switch (error.code) {
      'invalid_credentials' => const InvalidCredentialsFailure(),
      'user_already_exists' || 'email_exists' =>
        const EmailAlreadyRegisteredFailure(),
      'weak_password' || 'same_password' => const WeakPasswordFailure(),
      'otp_expired' || 'otp_disabled' => const InvalidCodeFailure(),
      'over_email_send_rate_limit' ||
      'over_request_rate_limit' => const RateLimitedFailure(),
      // Sin código HTTP no hubo respuesta del servidor; con código (5xx) sí.
      _ when error is AuthRetryableFetchException && error.statusCode == null =>
        const NetworkFailure(),
      _ => const UnexpectedFailure(),
    };
  }
  if (error is PostgrestException) {
    return AppFailure.fromApiError(code: error.code);
  }
  if (error is Exception) return const NetworkFailure();
  return const UnexpectedFailure();
}
