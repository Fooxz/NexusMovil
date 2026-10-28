import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/core/errors/app_failure.dart';
import 'package:prueba01/features/account/data/account_json.dart';
import 'package:prueba01/features/account/data/mock_account_repository.dart';
import 'package:prueba01/features/account/data/mock_directory.dart';
import 'package:prueba01/features/account/data/supabase_account_repository.dart';
import 'package:prueba01/features/account/domain/account_models.dart';
import 'package:prueba01/features/auth/data/mock_auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('accountFromJson (API_CONTRATO parte 7)', () {
    test('lee una cuenta de tienda con lo pendiente del primer ingreso', () {
      final account = accountFromJson({
        'userId': 'u-1',
        'role': 'provider',
        'fullName': 'Laura Gómez',
        'mustChangePassword': true,
        'pendingDocuments': [
          {'code': 'terms', 'version': '1.0', 'title': 'Términos y condiciones'},
        ],
        'provider': {'id': 'prov-1', 'displayName': 'Tienda Uno', 'status': 'active'},
      });

      expect(account.role, AccountRole.provider);
      expect(account.mustChangePassword, isTrue);
      expect(account.pendingDocuments.single.code, 'terms');
      expect(account.store?.displayName, 'Tienda Uno');
      expect(account.store?.status, StoreStatus.active);
      expect(account.needsStoreSetup, isTrue);
      expect(account.canBuy, isFalse);
    });

    test('un rol desconocido se lee como cliente y una tienda desconocida como suspendida', () {
      final account = accountFromJson({
        'userId': 'u-2',
        'role': 'superuser',
        'mustChangePassword': false,
        'pendingDocuments': <Object?>[],
        'provider': {'id': 'p', 'displayName': 'P', 'status': 'otro'},
      });
      expect(account.role, AccountRole.customer);
      expect(account.canBuy, isTrue);
      expect(account.store?.status, StoreStatus.suspended);
    });

    test('falla si falta un campo obligatorio', () {
      expect(() => accountFromJson({'userId': 'u'}), throwsFormatException);
    });
  });

  group('SupabaseAccountRepository', () {
    final accountJson = {
      'userId': 'u-1',
      'role': 'customer',
      'mustChangePassword': false,
      'pendingDocuments': <Object?>[],
      'provider': null,
    };

    test('consulta get_my_account y envía las versiones aceptadas', () async {
      final calls = <(String, Map<String, Object?>)>[];
      final repository = SupabaseAccountRepository((function, params) async {
        calls.add((function, params));
        return accountJson;
      });

      expect((await repository.getMyAccount()).role, AccountRole.customer);
      await repository.acceptDocuments(const [
        PendingDocument(code: 'terms', version: '1.0', title: 'Términos'),
      ]);

      expect(calls[0].$1, 'get_my_account');
      expect(calls[0].$2, isEmpty);
      expect(calls[1].$1, 'accept_current_documents');
      expect(calls[1].$2, {
        'documents': [
          {'code': 'terms', 'version': '1.0'},
        ],
      });
    });

    test('traduce los errores del backend', () async {
      final repository = SupabaseAccountRepository(
        (function, params) async => throw const PostgrestException(
          message: 'Acepta los términos',
          code: 'CONSENT_REQUIRED',
        ),
      );
      expect(repository.acceptDocuments(const []), throwsA(isA<DocumentsPendingFailure>()));
    });
  });

  group('MockAccountRepository', () {
    late MockAuthRepository auth;
    late MockDirectory directory;
    late MockAccountRepository repository;

    setUp(() {
      auth = MockAuthRepository(latency: Duration.zero);
      directory = MockDirectory();
      repository = MockAccountRepository(auth, directory, latency: Duration.zero);
    });

    test('toda cuenta del registro es cliente', () async {
      await auth.signUp(
        fullName: 'Ana',
        email: 'ana@nexus.test',
        password: 'Nexus12345',
        acceptedDocuments: MockAuthRepository.documents,
      );
      final account = await repository.getMyAccount();
      expect(account.role, AccountRole.customer);
      expect(account.needsStoreSetup, isFalse);
    });

    test('una cuenta de tienda creada por un administrador completa el primer ingreso', () async {
      final id = auth.createAccount(email: 'tienda@nexus.test', fullName: 'Tienda', password: 'Temporal123');
      directory.roles[id] = AccountRole.provider;
      directory.provisioned.add(id);
      await auth.signIn(email: 'tienda@nexus.test', password: 'Temporal123');

      var account = await repository.getMyAccount();
      expect(account.mustChangePassword, isTrue);
      expect(account.pendingDocuments, hasLength(2));

      await auth.changePassword('Definitiva123');
      account = await repository.getMyAccount();
      expect(account.mustChangePassword, isFalse);

      await expectLater(
        repository.acceptDocuments(account.pendingDocuments.take(1).toList()),
        throwsA(isA<DocumentsPendingFailure>()),
      );
      account = await repository.acceptDocuments(account.pendingDocuments);
      expect(account.pendingDocuments, isEmpty);
      expect(account.needsStoreSetup, isFalse);
    });

    test('cambiar a la misma contraseña se rechaza', () async {
      auth.createAccount(email: 't@nexus.test', fullName: 'T', password: 'Temporal123');
      await auth.signIn(email: 't@nexus.test', password: 'Temporal123');
      expect(auth.changePassword('Temporal123'), throwsA(isA<WeakPasswordFailure>()));
    });
  });
}
