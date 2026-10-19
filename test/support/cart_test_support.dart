import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:prueba01/features/auth/auth_providers.dart';
import 'package:prueba01/features/auth/data/mock_auth_repository.dart';
import 'package:prueba01/features/cart/presentation/cart_actions.dart';
import 'package:prueba01/features/catalog/catalog_providers.dart';
import 'package:prueba01/features/catalog/data/mock_product_repository.dart';
import 'package:prueba01/features/profile/data/mock_profile_repository.dart';
import 'package:prueba01/features/profile/profile_providers.dart';
import 'package:prueba01/main.dart';

/// Ofertas del `MockProductRepository` según su stock simulado.
abstract final class MockOffers {
  /// RTX 5090 de TecnoPartes: 20 unidades, se pueden llevar hasta 10.
  static const rtx5090Plenty = 'off-tp-rtx5090';

  /// RTX 5090 de Mundo PC: 3 unidades.
  static const rtx5090Few = 'off-mp-rtx5090';

  /// Ryzen 9 9950X (Tienda demo): 20 unidades, hasta 10.
  static const ryzen = 'mock-offer-ryzen-9-9950x';

  /// Kraken Elite 360 (Tienda demo): agotado.
  static const krakenOutOfStock = 'mock-offer-kraken-elite-360';
}

/// Mocks reales de catálogo, cuentas y perfil sin latencia. El carrito usa
/// `MockCartRepository`, que `cartRepositoryProvider` elige con estos mocks.
class CartTestBed {
  CartTestBed()
    : products = MockProductRepository(latency: Duration.zero),
      auth = MockAuthRepository(latency: Duration.zero) {
    profile = MockProfileRepository(auth, latency: Duration.zero);
  }

  final MockProductRepository products;
  final MockAuthRepository auth;
  late final MockProfileRepository profile;

  List<Override> get overrides => [
    productRepositoryProvider.overrideWithValue(products),
    authRepositoryProvider.overrideWithValue(auth),
    profileRepositoryProvider.overrideWithValue(profile),
  ];

  ProviderContainer container() => ProviderContainer(
    overrides: overrides,
    retry: (retryCount, error) => null,
  );

  Future<void> createAccount({
    String email = 'ana@nexus.test',
    bool keepSignedIn = true,
  }) async {
    await auth.signUp(
      fullName: 'Ana Pérez',
      email: email,
      password: 'Nexus12345',
      acceptedDocuments: MockAuthRepository.documents,
    );
    if (!keepSignedIn) await auth.signOut();
  }

  /// La app con sus rutas reales y el contador del carrito.
  Widget app({required Widget home}) => ProviderScope(
    overrides: overrides,
    retry: (retryCount, error) => null,
    child: MaterialApp(
      builder: (context, child) => CartBadgeHost(child: child!),
      onGenerateRoute: generateNexusRoute,
      home: home,
    ),
  );
}
