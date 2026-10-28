import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:prueba01/features/account/account_providers.dart';
import 'package:prueba01/features/account/data/mock_directory.dart';
import 'package:prueba01/features/account/domain/account_models.dart';
import 'package:prueba01/features/auth/auth_providers.dart';
import 'package:prueba01/features/auth/data/mock_auth_repository.dart';
import 'package:prueba01/features/catalog/catalog_providers.dart';
import 'package:prueba01/features/catalog/data/mock_product_repository.dart';
import 'package:prueba01/features/profile/data/mock_profile_repository.dart';
import 'package:prueba01/features/profile/profile_providers.dart';
import 'package:prueba01/main.dart';

const rolePassword = 'Nexus12345';

/// Mocks sin latencia para probar la app con cada rol: cuentas, directorio
/// de roles y tiendas, perfil y catálogo.
class RoleTestBed {
  RoleTestBed()
    : auth = MockAuthRepository(latency: Duration.zero),
      directory = MockDirectory(),
      products = MockProductRepository(latency: Duration.zero) {
    profile = MockProfileRepository(auth, latency: Duration.zero);
  }

  final MockAuthRepository auth;
  final MockDirectory directory;
  final MockProductRepository products;
  late final MockProfileRepository profile;

  List<Override> get overrides => [
    authRepositoryProvider.overrideWithValue(auth),
    mockDirectoryProvider.overrideWithValue(directory),
    profileRepositoryProvider.overrideWithValue(profile),
    productRepositoryProvider.overrideWithValue(products),
  ];

  /// Cliente registrado. Con [signedIn] queda con la sesión iniciada.
  Future<String> customer({
    String email = 'cliente@nexus.test',
    bool signedIn = true,
  }) async {
    await auth.signUp(
      fullName: 'Cliente Prueba',
      email: email,
      password: rolePassword,
      acceptedDocuments: MockAuthRepository.documents,
    );
    final id = auth.currentUser!.id;
    if (!signedIn) await auth.signOut();
    return id;
  }

  /// Cuenta de tienda creada por un administrador. Con [provisioned] todavía
  /// debe cambiar la contraseña y aceptar los documentos.
  Future<String> store({
    String email = 'tienda@nexus.test',
    bool provisioned = false,
    StoreStatus status = StoreStatus.active,
    bool signedIn = true,
  }) async {
    final id = auth.createAccount(email: email, fullName: 'Dueña Tienda', password: rolePassword);
    directory.roles[id] = AccountRole.provider;
    directory.stores['store-$id'] = MockStore(
      id: 'store-$id',
      legalName: 'Tienda Prueba S.A.S.',
      displayName: 'Tienda Prueba',
      taxId: '900123456-7',
      contactEmail: 'ventas@tienda.test',
      status: status,
      userId: id,
    );
    if (provisioned) directory.provisioned.add(id);
    if (signedIn) await auth.signIn(email: email, password: rolePassword);
    return id;
  }

  Future<String> admin({String email = 'admin@nexus.test'}) async {
    final id = await customer(email: email);
    directory.roles[id] = AccountRole.admin;
    return id;
  }

  Widget app() => ProviderScope(
    overrides: overrides,
    retry: (retryCount, error) => null,
    child: const NexusApp(),
  );
}
