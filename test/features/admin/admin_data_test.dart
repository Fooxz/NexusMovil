import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/core/errors/app_failure.dart';
import 'package:prueba01/features/account/data/mock_account_repository.dart';
import 'package:prueba01/features/account/data/mock_directory.dart';
import 'package:prueba01/features/account/domain/account_models.dart';
import 'package:prueba01/features/admin/data/admin_json.dart';
import 'package:prueba01/features/admin/data/mock_admin_repository.dart';
import 'package:prueba01/features/admin/data/supabase_admin_repository.dart';
import 'package:prueba01/features/admin/domain/admin_models.dart';
import 'package:prueba01/features/auth/data/mock_auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _storeJson = {
  'id': 'prov-1',
  'legalName': 'Tienda Uno S.A.S.',
  'displayName': 'Tienda Uno',
  'taxId': '900123456-7',
  'contactEmail': 'ventas@uno.co',
  'status': 'active',
  'verificationNote': 'Visita',
  'accountEmail': 'dueno@uno.co',
  'publishedOffers': 4,
  'createdAt': '2026-10-27T10:00:00Z',
};

const _store = StoreInput(
  legalName: 'Tienda Nueva S.A.S.',
  displayName: 'Tienda Nueva',
  taxId: '900555777-1',
  contactEmail: 'ventas@nueva.co',
);
const _account = NewAccountInput(email: 'dueno@nueva.co', fullName: 'Laura Gómez');

void main() {
  test('lee la tienda y el resultado del alta', () {
    final store = adminStoreFromJson(_storeJson);
    expect(store.status, StoreStatus.active);
    expect(store.accountEmail, 'dueno@uno.co');
    expect(store.publishedOffers, 4);

    final result = provisionResultFromJson({'provider': _storeJson, 'temporaryPassword': 'Tq7!mZ2#pW9x\$Kd4@Vh6'});
    expect(result.store.id, 'prov-1');
    expect(result.temporaryPassword, hasLength(20));
  });

  group('SupabaseAdminRepository', () {
    test('las RPC administrativas y la Edge Function reciben lo que esperan', () async {
      final rpcCalls = <(String, Map<String, Object?>)>[];
      final bodies = <Map<String, Object?>>[];
      final repository = SupabaseAdminRepository(
        (function, params) async {
          rpcCalls.add((function, params));
          return function == 'admin_get_providers' ? [_storeJson] : _storeJson;
        },
        (body) async {
          bodies.add(body);
          return {'provider': _storeJson, 'temporaryPassword': 'Clave-Temporal-2026'};
        },
      );

      await repository.getStores(search: 'uno');
      await repository.setStoreStatus('prov-1', StoreStatus.suspended, reason: 'Prueba');
      await repository.updateStore('prov-1', _store, confirmSimilarName: true);
      await repository.createStore(_store, _account);
      await repository.createAccount('prov-1', _account);
      await repository.resetPassword('prov-1');

      expect(rpcCalls[0].$1, 'admin_get_providers');
      expect(rpcCalls[0].$2, {'search': 'uno'});
      expect(rpcCalls[1].$2, {'id': 'prov-1', 'status': 'suspended', 'reason': 'Prueba'});
      expect(rpcCalls[2].$2['confirm_similar_name'], isTrue);
      expect(bodies.map((body) => body['action']), ['create_provider', 'create_account', 'reset_password']);
      expect(bodies[0]['account'], {'email': 'dueno@nueva.co', 'fullName': 'Laura Gómez'});
      expect(bodies[1]['providerId'], 'prov-1');
    });

    test('traduce los errores de la Edge Function', () async {
      SupabaseAdminRepository failing(int status, Map<String, Object?> body) => SupabaseAdminRepository(
        (function, params) async => null,
        (requestBody) async => throw FunctionException(status: status, details: body),
      );

      await expectLater(
        failing(409, {
          'code': 'SIMILAR_STORE_NAME',
          'message': 'Ya hay una tienda llamada Mundo PC.',
          'details': '{"providerId": "prov-mundopc", "displayName": "Mundo PC"}',
        }).createStore(_store, _account),
        throwsA(isA<SimilarStoreNameFailure>().having((f) => f.existingName, 'existingName', 'Mundo PC')),
      );
      await expectLater(
        failing(403, {'code': 'FORBIDDEN', 'message': 'Solo administradores'}).resetPassword('prov-1'),
        throwsA(isA<ForbiddenFailure>()),
      );
      await expectLater(
        failing(409, {'code': 'EMAIL_EXISTS', 'message': 'Ya existe'}).createStore(_store, _account),
        throwsA(isA<StoreEmailTakenFailure>()),
      );
    });
  });

  group('MockAdminRepository', () {
    late MockAuthRepository auth;
    late MockDirectory directory;
    late MockAdminRepository repository;

    setUp(() async {
      auth = MockAuthRepository(latency: Duration.zero);
      directory = MockDirectory();
      repository = MockAdminRepository(auth, directory, latency: Duration.zero);
      await auth.signUp(
        fullName: 'Admin',
        email: 'admin@zz.test',
        password: 'Nexus12345',
        acceptedDocuments: MockAuthRepository.documents,
      );
    });

    void makeAdmin() => directory.roles[auth.currentUser!.id] = AccountRole.admin;

    test('solo un administrador administra tiendas', () {
      expect(repository.getStores(), throwsA(isA<ForbiddenFailure>()));
    });

    test('la cuenta creada entra con la contraseña temporal y debe completar el primer ingreso', () async {
      makeAdmin();
      final result = await repository.createStore(_store, _account);
      expect(result.store.accountEmail, 'dueno@nueva.co');
      expect(result.temporaryPassword, hasLength(20));

      await auth.signOut();
      await auth.signIn(email: 'dueno@nueva.co', password: result.temporaryPassword);
      final account = await MockAccountRepository(auth, directory, latency: Duration.zero).getMyAccount();
      expect(account.role, AccountRole.provider);
      expect(account.mustChangePassword, isTrue);
      expect(account.pendingDocuments, hasLength(2));
      expect(account.store?.displayName, 'Tienda Nueva');
    });

    test('avisa del nombre parecido, protege el NIT y vincula tiendas existentes', () async {
      makeAdmin();
      await expectLater(
        repository.createStore(
          const StoreInput(legalName: 'Otra S.A.S.', displayName: 'MUNDO-PC', taxId: '901000000-1', contactEmail: 'a@b.co'),
          _account,
        ),
        throwsA(isA<SimilarStoreNameFailure>()),
      );
      await expectLater(
        repository.createStore(
          const StoreInput(legalName: 'Otra S.A.S.', displayName: 'Otra', taxId: '900111222-1', contactEmail: 'a@b.co'),
          _account,
        ),
        throwsA(isA<TaxIdTakenFailure>()),
      );

      final linked = await repository.createAccount('prov-mundopc', _account);
      expect(linked.store.accountEmail, 'dueno@nueva.co');
      expect(linked.store.status, StoreStatus.active);
      await expectLater(
        repository.createAccount('prov-mundopc', const NewAccountInput(email: 'otro@zz.test', fullName: 'Otro')),
        throwsA(isA<StoreHasAccountFailure>()),
      );
    });

    test('suspende y regenera la contraseña', () async {
      makeAdmin();
      final created = await repository.createStore(_store, _account);
      final suspended = await repository.setStoreStatus(created.store.id, StoreStatus.suspended, reason: 'Documentos vencidos');
      expect(suspended.status, StoreStatus.suspended);

      final reset = await repository.resetPassword(created.store.id);
      expect(reset.temporaryPassword, isNot(created.temporaryPassword));
      await auth.signOut();
      await expectLater(
        auth.signIn(email: 'dueno@nueva.co', password: created.temporaryPassword),
        throwsA(isA<InvalidCredentialsFailure>()),
      );
      await auth.signIn(email: 'dueno@nueva.co', password: reset.temporaryPassword);
    });
  });
}
