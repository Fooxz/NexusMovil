// Prueba de integración de los roles, el catálogo por oferta y las
// publicaciones de tiendas contra el Supabase LOCAL, con los repositorios
// reales de la app. Se salta sin configuración.
//
// El flujo de tiendas necesita además:
// - la Edge Function servida: `npx supabase functions serve admin-providers`;
// - un administrador habilitado por SQL (backend/README.md) y sus datos:
//   --dart-define=INTEGRATION_ADMIN_EMAIL=... --dart-define=INTEGRATION_ADMIN_PASSWORD=...
@Tags(['integration'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/core/config/env.dart';
import 'package:prueba01/core/errors/app_failure.dart';
import 'package:prueba01/features/account/data/supabase_account_repository.dart';
import 'package:prueba01/features/account/domain/account_models.dart';
import 'package:prueba01/features/admin/data/supabase_admin_repository.dart';
import 'package:prueba01/features/admin/domain/admin_models.dart';
import 'package:prueba01/features/auth/data/supabase_auth_repository.dart';
import 'package:prueba01/features/cart/data/supabase_cart_repository.dart';
import 'package:prueba01/features/catalog/data/supabase_product_repository.dart';
import 'package:prueba01/features/catalog/domain/product.dart';
import 'package:prueba01/features/catalog/domain/product_filters.dart';
import 'package:prueba01/features/provider_portal/data/supabase_portal_repository.dart';
import 'package:prueba01/features/provider_portal/domain/portal_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../support/integration_support.dart';

final _png = Uint8List.fromList(base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
));

void main() {
  const env = AppEnv.fromEnvironment();
  final skip = integrationSkip(env);
  const adminEmail = String.fromEnvironment('INTEGRATION_ADMIN_EMAIL');
  const adminPassword = String.fromEnvironment('INTEGRATION_ADMIN_PASSWORD');
  final storeSkip = skip != false
      ? skip
      : adminEmail.isEmpty
      ? 'Sin INTEGRATION_ADMIN_EMAIL/INTEGRATION_ADMIN_PASSWORD (ver backend/README.md)'
      : false;

  SupabaseClient newClient() => SupabaseClient(
    env.supabaseUrl,
    env.supabasePublishableKey,
    authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
  );

  final runId = DateTime.now().millisecondsSinceEpoch;

  test('una cuenta del registro es cliente y el catálogo trae una tarjeta por tienda', () async {
    final client = newClient();
    final auth = SupabaseAuthRepository(client);
    await auth.signUp(
      fullName: 'Cliente Roles',
      email: 'cliente.roles.$runId@nexus.test',
      password: 'Nexus12345',
      acceptedDocuments: await auth.getCurrentLegalDocuments(),
    );
    final account = await SupabaseAccountRepository.fromClient(client).getMyAccount();
    expect(account.role, AccountRole.customer);
    expect(account.canBuy, isTrue);

    final products = SupabaseProductRepository.fromClient(newClient());
    final rtx = await products.getOffers(filters: const ProductFilters(search: 'rtx 5090'));
    final cards = rtx.items.where((offer) => offer.productId == 'rtx-5090').toList();
    expect(cards.map((offer) => offer.providerId).toSet(), hasLength(cards.length),
        reason: 'una tarjeta por tienda');
    expect(cards.every((offer) => offer.offerCount == cards.length), isTrue);
    expect(await products.getStores(category: ProductCategory.gpu), isNotEmpty);

    await expectLater(
      SupabaseAdminRepository.fromClient(client).getStores(),
      throwsA(isA<ForbiddenFailure>()),
    );
  }, skip: skip);

  test('el administrador crea una tienda, la tienda publica y su tarjeta aparece', () async {
    // Administrador
    final adminClient = newClient();
    await SupabaseAuthRepository(adminClient).signIn(email: adminEmail, password: adminPassword);
    final admin = SupabaseAdminRepository.fromClient(adminClient);
    final created = await admin.createStore(
      StoreInput(
        legalName: 'ZZINT Tienda $runId S.A.S.',
        displayName: 'ZZINT Tienda $runId',
        taxId: '9${runId.toString().substring(runId.toString().length - 8)}-1',
        contactEmail: 'ventas.$runId@nexus.test',
        verificationNote: 'Prueba de integración',
      ),
      NewAccountInput(email: 'tienda.$runId@nexus.test', fullName: 'Dueña Integración'),
    );
    expect(created.temporaryPassword, hasLength(20));

    // Primer ingreso de la tienda
    final storeClient = newClient();
    final storeAuth = SupabaseAuthRepository(storeClient);
    await storeAuth.signIn(email: 'tienda.$runId@nexus.test', password: created.temporaryPassword);
    final accounts = SupabaseAccountRepository.fromClient(storeClient);
    final portal = SupabasePortalRepository.fromClient(storeClient);
    var account = await accounts.getMyAccount();
    expect(account.role, AccountRole.provider);
    expect(account.mustChangePassword, isTrue);
    await expectLater(portal.getMyOffers(), throwsA(isA<PasswordChangeRequiredFailure>()));

    await storeAuth.changePassword('Definitiva-$runId');
    await expectLater(portal.getMyOffers(), throwsA(isA<DocumentsPendingFailure>()));
    account = await accounts.acceptDocuments((await accounts.getMyAccount()).pendingDocuments);
    expect(account.needsStoreSetup, isFalse);
    final storeId = account.store!.id;

    // Publica un producto nuevo con su imagen
    final path = await portal.uploadImage(storeId: storeId, bytes: _png, extension: 'png', contentType: 'image/png');
    ProductInput gpu(String model) => ProductInput(
      category: ProductCategory.gpu,
      name: 'ZZINT Gráfica $runId',
      brand: 'ZZINT',
      model: model,
      attributes: const {'chipset': 'ZZINT', 'vram_gb': 8, 'tdp_w': 150, 'length_mm': 240},
      images: [path],
    );
    final detail = await portal.createProduct(
      gpu('INT-$runId'),
      const OfferInput(priceCents: 150000000, oldPriceCents: 170000000, stockUnits: 3),
    );
    expect(detail.offer.visible, isTrue);
    expect(detail.images.single.path, path);

    final products = SupabaseProductRepository.fromClient(newClient());
    final mine = await products.getOffers(filters: ProductFilters(search: 'zzint grafica $runId'));
    expect(mine.items.single.providerName, 'ZZINT Tienda $runId');
    expect(mine.items.single.oldPriceCents, 170000000);
    expect((await products.getOffers(filters: ProductFilters(providerId: storeId))).total, 1);

    // Oferta sobre un producto existente; la ficha compartida no se edita
    await portal.createOffer('rtx-5090', const OfferInput(priceCents: 700000000, stockUnits: 2));
    final rtx = await products.getOffers(filters: ProductFilters(search: 'rtx 5090', providerId: storeId));
    expect(rtx.items.single.productId, 'rtx-5090');
    await expectLater(portal.updateProduct('rtx-5090', gpu('RTX 5090')), throwsA(isA<ProductLockedFailure>()));
    await expectLater(
      portal.createProduct(gpu('int $runId'), const OfferInput(priceCents: 100000, stockUnits: 1)),
      throwsA(isA<ProductExistsFailure>()),
    );

    // Roles exclusivos: una tienda no compra ni administra
    await expectLater(SupabaseCartRepository.fromClient(storeClient).load(), throwsA(isA<CustomerOnlyFailure>()));
    await expectLater(SupabaseAdminRepository.fromClient(storeClient).getStores(), throwsA(isA<ForbiddenFailure>()));

    // Suspendida, su tarjeta sale del catálogo
    await admin.setStoreStatus(storeId, StoreStatus.suspended, reason: 'Prueba de integración');
    expect((await products.getOffers(filters: ProductFilters(search: 'zzint grafica $runId'))).total, 0);
    await expectLater(portal.getMyOffers(), throwsA(isA<StoreNotActiveFailure>()));
  }, skip: storeSkip);
}
