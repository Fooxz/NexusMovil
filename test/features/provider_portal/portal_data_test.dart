import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/core/errors/app_failure.dart';
import 'package:prueba01/features/account/data/mock_directory.dart';
import 'package:prueba01/features/account/domain/account_models.dart';
import 'package:prueba01/features/auth/data/mock_auth_repository.dart';
import 'package:prueba01/features/catalog/data/mock_product_repository.dart';
import 'package:prueba01/features/catalog/domain/product.dart';
import 'package:prueba01/features/provider_portal/data/mock_portal_repository.dart';
import 'package:prueba01/features/provider_portal/data/portal_json.dart';
import 'package:prueba01/features/provider_portal/data/supabase_portal_repository.dart';
import 'package:prueba01/features/provider_portal/domain/portal_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Respuesta de `get_my_offer` como la arma el backend.
const _detailJson = {
  'offerId': 'off-1',
  'productId': 'prod-1',
  'name': 'ZZ Gráfica',
  'brand': 'ZZ',
  'model': 'ZZ-G1',
  'category': 'gpu',
  'imageUrl': 'http://127.0.0.1:54321/storage/v1/object/public/product-images/prov-a/a.jpg',
  'priceCents': 250000000,
  'oldPriceCents': 270000000,
  'stockUnits': 7,
  'stockLevel': 'stable',
  'status': 'published',
  'externalSku': 'SKU-1',
  'visible': true,
  'canEditSheet': true,
  'updatedAt': '2026-10-27T10:00:00Z',
  'summary': '12 GB',
  'quickSpecs': ['12 GB'],
  'specs': [
    {'label': 'VRAM', 'value': '12 GB'},
  ],
  'attributes': {'chipset': 'ZZ', 'vram_gb': 12},
  'images': [
    {'url': 'http://127.0.0.1:54321/storage/v1/object/public/product-images/prov-a/a.jpg', 'path': 'prov-a/a.jpg'},
  ],
  'sellers': 2,
};

const _offer = OfferInput(priceCents: 250000000, oldPriceCents: 270000000, stockUnits: 7);

ProductInput _gpu(String model, {List<String> images = const ['x']}) => ProductInput(
  category: ProductCategory.gpu,
  name: 'ZZ Gráfica $model',
  brand: 'ZZ',
  model: model,
  attributes: const {'chipset': 'ZZ', 'vram_gb': 12, 'tdp_w': 200, 'length_mm': 280},
  images: images,
);

void main() {
  group('JSON del portal (API_CONTRATO parte 8)', () {
    test('lee la publicación con su ficha', () {
      final detail = myOfferDetailFromJson(_detailJson);
      expect(detail.offer.status, OfferStatus.published);
      expect(detail.offer.stockUnits, 7);
      expect(detail.offer.canEditSheet, isTrue);
      expect(detail.attributes, {'chipset': 'ZZ', 'vram_gb': 12});
      expect(detail.images.single.path, 'prov-a/a.jpg');
      expect(detail.sellers, 2);
    });

    test('lee las fichas con la oferta de la tienda y la plantilla de atributos', () {
      final sheet = catalogSheetFromJson({
        'productId': 'rtx-5090',
        'name': 'RTX 5090',
        'brand': 'NVIDIA',
        'model': 'RTX 5090',
        'category': 'gpu',
        'sellers': 2,
        'myOffer': {'offerId': 'o', 'status': 'retired'},
      });
      expect(sheet.myOfferStatus, OfferStatus.retired);

      final definition = attributeDefinitionFromJson({
        'key': 'socket',
        'label': 'Socket',
        'data_type': 'enum',
        'unit': null,
        'is_required': true,
        'allowed_values': ['AM4', 'AM5'],
      });
      expect(definition.type, AttributeType.choice);
      expect(definition.isRequired, isTrue);
      expect(definition.allowedValues, ['AM4', 'AM5']);
    });

    test('los datos de la oferta van en centavos y sin el estado retirado', () {
      expect(_offer.toJson(), {
        'priceCents': 250000000,
        'oldPriceCents': 270000000,
        'stockUnits': 7,
        'status': 'published',
      });
    });
  });

  group('SupabasePortalRepository', () {
    late List<(String, Map<String, Object?>)> calls;
    late List<(String, String)> uploads;
    late SupabasePortalRepository repository;

    setUp(() {
      calls = [];
      uploads = [];
      repository = SupabasePortalRepository(
        (function, params) async {
          calls.add((function, params));
          return function == 'get_my_offers'
              ? {'items': [_detailJson], 'total': 1, 'page': 0, 'pageSize': 20}
              : _detailJson;
        },
        loadTemplate: (category) async => [
          {'key': 'chipset', 'label': 'Chip', 'data_type': 'text', 'is_required': true},
        ],
        upload: (path, bytes, contentType) async => uploads.add((path, contentType)),
      );
    });

    test('envía cada acción a su RPC, sin el id de la tienda', () async {
      await repository.getMyOffers(status: OfferStatus.paused);
      await repository.createProduct(_gpu('ZZ-G1'), _offer, confirmDistinct: true);
      await repository.updateOffer('prod-1', _offer);
      await repository.retireOffer('prod-1');

      expect(calls.map((call) => call.$1), ['get_my_offers', 'create_my_product', 'update_my_offer', 'retire_my_offer']);
      expect(calls[0].$2, {'status': 'paused', 'page': 0, 'page_size': 20});
      expect(calls[1].$2['confirm_distinct'], isTrue);
      expect((calls[1].$2['product']! as Map)['model'], 'ZZ-G1');
      expect(calls[2].$2, {'product_id': 'prod-1', 'offer': _offer.toJson()});
      for (final call in calls) {
        expect(call.$2.keys, isNot(contains('provider_id')));
      }
    });

    test('sube la imagen a la carpeta de la tienda con un nombre aleatorio', () async {
      final path = await repository.uploadImage(
        storeId: 'prov-a',
        bytes: Uint8List(3),
        extension: 'png',
        contentType: 'image/png',
      );
      expect(path, matches(RegExp(r'^prov-a/[0-9a-f]{32}\.png$')));
      expect(uploads.single, (path, 'image/png'));
      expect(
        (await repository.getAttributeTemplate(ProductCategory.gpu)).single.key,
        'chipset',
      );
    });

    test('si Storage rechaza la subida, la tienda no tiene permiso', () async {
      final rejecting = SupabasePortalRepository(
        (function, params) async => null,
        loadTemplate: (category) async => const [],
        upload: (path, bytes, contentType) async =>
            throw const StorageException('new row violates row-level security policy', statusCode: '403'),
      );
      expect(
        rejecting.uploadImage(storeId: 'prov-a', bytes: Uint8List(1), extension: 'jpg', contentType: 'image/jpeg'),
        throwsA(isA<ForbiddenFailure>()),
      );
    });

    test('traduce los conflictos de duplicados', () async {
      final duplicated = SupabasePortalRepository(
        (function, params) async => throw const PostgrestException(
          message: 'Este producto ya está en el catálogo.',
          code: 'PRODUCT_EXISTS',
          details: '{"productId": "rtx-5090", "name": "RTX 5090"}',
        ),
        loadTemplate: (category) async => const [],
        upload: (path, bytes, contentType) async {},
      );
      await expectLater(
        duplicated.createProduct(_gpu('RTX 5090'), _offer),
        throwsA(isA<ProductExistsFailure>().having((f) => f.productId, 'productId', 'rtx-5090')),
      );
    });
  });

  group('MockPortalRepository', () {
    late MockAuthRepository auth;
    late MockDirectory directory;
    late MockPortalRepository repository;

    Future<String> signInStore(String email, String storeId) async {
      final id = auth.createAccount(email: email, fullName: 'Tienda', password: 'Nexus12345');
      directory.roles[id] = AccountRole.provider;
      directory.stores[storeId] = MockStore(
        id: storeId,
        legalName: '$storeId S.A.S.',
        displayName: storeId,
        taxId: '900000000-0',
        contactEmail: '$storeId@zz.test',
        userId: id,
      );
      await auth.signIn(email: email, password: 'Nexus12345');
      return id;
    }

    Future<String> upload(String storeId) =>
        repository.uploadImage(storeId: storeId, bytes: Uint8List(1), extension: 'png', contentType: 'image/png');

    setUp(() {
      auth = MockAuthRepository(latency: Duration.zero);
      directory = MockDirectory();
      repository = MockPortalRepository(
        auth,
        directory,
        MockProductRepository(latency: Duration.zero),
        latency: Duration.zero,
      );
    });

    test('un cliente no publica', () async {
      await auth.signUp(
        fullName: 'Ana',
        email: 'ana@zz.test',
        password: 'Nexus12345',
        acceptedDocuments: MockAuthRepository.documents,
      );
      expect(repository.getMyOffers(), throwsA(isA<ForbiddenFailure>()));
    });

    test('publica, detecta duplicados y respeta la ficha compartida', () async {
      await signInStore('a@zz.test', 'tienda-a');
      final created = await repository.createProduct(_gpu('ZZ-G1', images: [await upload('tienda-a')]), _offer);
      expect(created.offer.canEditSheet, isTrue);
      expect((await repository.getMyOffers()).items.single.productId, created.offer.productId);

      await expectLater(
        repository.createProduct(_gpu('zz g1', images: [await upload('tienda-a')]), _offer),
        throwsA(isA<ProductExistsFailure>()),
      );

      // Otra tienda vende el mismo producto: la ficha queda fija.
      await auth.signOut();
      await signInStore('b@zz.test', 'tienda-b');
      await repository.createOffer(created.offer.productId, _offer);
      await expectLater(
        repository.updateProduct(created.offer.productId, _gpu('ZZ-G1', images: [await upload('tienda-b')])),
        throwsA(isA<ProductLockedFailure>()),
      );
      await auth.signOut();
      await auth.signIn(email: 'a@zz.test', password: 'Nexus12345');
      await expectLater(
        repository.updateProduct(created.offer.productId, _gpu('ZZ-G1', images: [await upload('tienda-a')])),
        throwsA(isA<ProductSharedFailure>()),
      );
    });

    test('exige imágenes subidas por la tienda y retira de forma lógica', () async {
      await signInStore('a@zz.test', 'tienda-a');
      await expectLater(
        repository.createProduct(_gpu('ZZ-G2', images: ['tienda-a/no-subida.png']), _offer),
        throwsA(isA<FieldValidationFailure>()),
      );
      final created = await repository.createProduct(_gpu('ZZ-G2', images: [await upload('tienda-a')]), _offer);
      final retired = await repository.retireOffer(created.offer.productId);
      expect(retired.offer.status, OfferStatus.retired);
      await expectLater(repository.updateOffer(created.offer.productId, _offer), throwsA(isA<OfferRetiredFailure>()));
      final again = await repository.createOffer(created.offer.productId, _offer);
      expect(again.offer.offerId, created.offer.offerId, reason: 'reactiva la misma oferta');
    });

    test('una tienda suspendida no opera', () async {
      await signInStore('a@zz.test', 'tienda-a');
      directory.stores['tienda-a']!.status = StoreStatus.suspended;
      expect(repository.getMyOffers(), throwsA(isA<StoreNotActiveFailure>()));
    });
  });
}
