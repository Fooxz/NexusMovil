import 'dart:async';

import '../../../core/errors/app_failure.dart';
import '../domain/auth_models.dart';
import '../domain/auth_repository.dart';

/// Cuentas en memoria para usar la app sin backend. Aplica las mismas reglas
/// que Supabase: contraseña de 8 caracteres con letras y números, correo
/// único y aceptación de los documentos vigentes.
///
/// El código de recuperación siempre es [recoveryCode].
class MockAuthRepository implements AuthRepository {
  MockAuthRepository({this.latency = const Duration(milliseconds: 300)});

  static const recoveryCode = '123456';

  static const documents = [
    LegalDocument(
      code: 'privacy',
      version: '1.0',
      title: 'Política de tratamiento de datos personales',
      content: 'BORRADOR PENDIENTE DE REVISIÓN LEGAL.\n\n'
          'Usamos tus datos para gestionar tu cuenta, tus compras y sus entregas.',
    ),
    LegalDocument(
      code: 'terms',
      version: '1.0',
      title: 'Términos y condiciones',
      content: 'BORRADOR PENDIENTE DE REVISIÓN LEGAL.\n\n'
          'NEXUS es un intermediario entre clientes y proveedores.',
    ),
  ];

  final Duration latency;
  final _accounts = <String, ({String id, String password, String fullName})>{};
  final _pendingResets = <String>{};
  final _changes = StreamController<AuthUser?>.broadcast();
  AuthUser? _currentUser;
  var _nextId = 1;

  /// Sin latencia no espera: dentro de `testWidgets` un `Future.delayed`
  /// solo avanza con `pump`, y las pruebas preparan datos sin bombear.
  Future<void> _simulateLatency() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  /// Nombre registrado de un usuario, para el perfil del mock.
  String? fullNameOf(String userId) {
    for (final account in _accounts.values) {
      if (account.id == userId) return account.fullName;
    }
    return null;
  }

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  Stream<AuthUser?> authStateChanges() async* {
    yield _currentUser;
    yield* _changes.stream;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _simulateLatency();
    final key = _key(email);
    final account = _accounts[key];
    if (account == null || account.password != password) {
      throw const InvalidCredentialsFailure();
    }
    _setUser(AuthUser(id: account.id, email: key));
  }

  @override
  Future<SignUpResult> signUp({
    required String fullName,
    required String email,
    required String password,
    required List<LegalDocument> acceptedDocuments,
  }) async {
    await _simulateLatency();
    final accepted = {
      for (final document in acceptedDocuments)
        '${document.code}@${document.version}',
    };
    if (!documents.every((d) => accepted.contains('${d.code}@${d.version}'))) {
      throw const ConsentRequiredFailure();
    }
    _checkPassword(password);
    final key = _key(email);
    if (_accounts.containsKey(key)) throw const EmailAlreadyRegisteredFailure();

    final id = 'mock-user-${_nextId++}';
    _accounts[key] = (id: id, password: password, fullName: fullName.trim());
    _setUser(AuthUser(id: id, email: key));
    return SignUpResult.signedIn;
  }

  @override
  Future<void> signOut() async {
    await _simulateLatency();
    _setUser(null);
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    await _simulateLatency();
    // Como Supabase, no revela si el correo existe.
    if (_accounts.containsKey(_key(email))) _pendingResets.add(_key(email));
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _simulateLatency();
    final key = _key(email);
    final account = _accounts[key];
    if (account == null ||
        !_pendingResets.contains(key) ||
        code.trim() != recoveryCode) {
      throw const InvalidCodeFailure();
    }
    _checkPassword(newPassword);
    _pendingResets.remove(key);
    _accounts[key] = (
      id: account.id,
      password: newPassword,
      fullName: account.fullName,
    );
    _setUser(AuthUser(id: account.id, email: key));
  }

  @override
  Future<List<LegalDocument>> getCurrentLegalDocuments() async {
    await _simulateLatency();
    return documents;
  }

  void _setUser(AuthUser? user) {
    _currentUser = user;
    _changes.add(user);
  }

  static String _key(String email) => email.trim().toLowerCase();

  static void _checkPassword(String password) {
    if (password.length < 8 ||
        !password.contains(RegExp('[A-Za-z]')) ||
        !password.contains(RegExp('[0-9]'))) {
      throw const WeakPasswordFailure();
    }
  }
}
