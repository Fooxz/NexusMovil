import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/core/errors/app_failure.dart';
import 'package:prueba01/features/auth/data/mock_auth_repository.dart';
import 'package:prueba01/features/auth/domain/auth_models.dart';

void main() {
  late MockAuthRepository auth;

  setUp(() => auth = MockAuthRepository(latency: Duration.zero));

  Future<SignUpResult> signUp({
    String email = 'ana@nexus.test',
    String password = 'Nexus12345',
    List<LegalDocument> documents = MockAuthRepository.documents,
  }) => auth.signUp(
    fullName: 'Ana',
    email: email,
    password: password,
    acceptedDocuments: documents,
  );

  test('signup needs every current document', () async {
    await expectLater(
      signUp(documents: MockAuthRepository.documents.take(1).toList()),
      throwsA(isA<ConsentRequiredFailure>()),
    );
    expect(auth.currentUser, isNull);
  });

  test('signup applies the password policy and unique emails', () async {
    await expectLater(signUp(password: 'corta1'), throwsA(isA<WeakPasswordFailure>()));
    expect(await signUp(), SignUpResult.signedIn);
    await expectLater(
      signUp(email: ' ANA@nexus.test '),
      throwsA(isA<EmailAlreadyRegisteredFailure>()),
    );
  });

  test('emits session changes, starting with the current user', () async {
    final events = <String?>[];
    final subscription = auth.authStateChanges().listen(
      (user) => events.add(user?.email),
    );
    await Future<void>.delayed(Duration.zero);
    await signUp();
    await auth.signOut();
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();

    expect(events, [null, 'ana@nexus.test', null]);
  });

  test('sign in rejects wrong credentials', () async {
    await signUp();
    await auth.signOut();

    await expectLater(
      auth.signIn(email: 'ana@nexus.test', password: 'Otra12345'),
      throwsA(isA<InvalidCredentialsFailure>()),
    );
    await auth.signIn(email: 'ana@nexus.test', password: 'Nexus12345');
    expect(auth.currentUser?.email, 'ana@nexus.test');
  });

  test('password reset needs a requested and valid code', () async {
    await signUp();
    await auth.signOut();

    await expectLater(
      auth.resetPassword(
        email: 'ana@nexus.test',
        code: MockAuthRepository.recoveryCode,
        newPassword: 'Nueva12345',
      ),
      throwsA(isA<InvalidCodeFailure>()),
    );

    await auth.requestPasswordReset('ana@nexus.test');
    await expectLater(
      auth.resetPassword(email: 'ana@nexus.test', code: '000000', newPassword: 'Nueva12345'),
      throwsA(isA<InvalidCodeFailure>()),
    );
    await auth.resetPassword(
      email: 'ana@nexus.test',
      code: MockAuthRepository.recoveryCode,
      newPassword: 'Nueva12345',
    );
    expect(auth.currentUser?.email, 'ana@nexus.test');

    await auth.signOut();
    await auth.signIn(email: 'ana@nexus.test', password: 'Nueva12345');
  });

  test('requesting a reset for an unknown email does not reveal it', () async {
    await auth.requestPasswordReset('nadie@nexus.test');
  });
}
