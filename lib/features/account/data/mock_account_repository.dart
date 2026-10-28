import '../../../core/errors/app_failure.dart';
import '../../auth/data/mock_auth_repository.dart';
import '../domain/account_models.dart';
import '../domain/account_repository.dart';
import 'mock_directory.dart';

/// Cuenta en memoria. Aplica las mismas reglas que `get_my_account`: toda
/// cuenta es cliente salvo que el directorio diga otra cosa, y las cuentas
/// creadas por un administrador cambian la contraseña y aceptan los
/// documentos en su primer ingreso.
class MockAccountRepository implements AccountRepository {
  MockAccountRepository(
    this._auth,
    this.directory, {
    this.latency = const Duration(milliseconds: 200),
  });

  final MockAuthRepository _auth;
  final MockDirectory directory;
  final Duration latency;

  Future<void> _simulateLatency() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  @override
  Future<Account> getMyAccount() async {
    await _simulateLatency();
    return _account();
  }

  @override
  Future<Account> acceptDocuments(List<PendingDocument> documents) async {
    await _simulateLatency();
    final userId = _userId();
    final accepted = {for (final d in documents) '${d.code}@${d.version}'};
    final complete = MockAuthRepository.documents.every(
      (d) => accepted.contains('${d.code}@${d.version}'),
    );
    if (!complete) throw const DocumentsPendingFailure();
    directory.acceptedDocuments.add(userId);
    return _account();
  }

  Account _account() {
    final userId = _userId();
    final provisioned = directory.provisioned.contains(userId);
    final pending = provisioned && !directory.acceptedDocuments.contains(userId);
    return Account(
      userId: userId,
      role: directory.roles[userId] ?? AccountRole.customer,
      fullName: _auth.fullNameOf(userId),
      mustChangePassword: provisioned && !_auth.hasChangedPassword(userId),
      pendingDocuments: [
        if (pending)
          for (final document in MockAuthRepository.documents)
            PendingDocument(
              code: document.code,
              version: document.version,
              title: document.title,
            ),
      ],
      store: directory.storeOf(userId)?.summary,
    );
  }

  String _userId() {
    final user = _auth.currentUser;
    if (user == null) throw const UnauthorizedFailure();
    return user.id;
  }
}
