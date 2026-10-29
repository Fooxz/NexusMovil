import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/features/provider_portal/data/mock_portal_repository.dart';
import 'package:prueba01/features/provider_portal/data/product_image_picker.dart';
import 'package:prueba01/features/provider_portal/domain/portal_models.dart';
import 'package:prueba01/features/provider_portal/presentation/my_offers_screen.dart';
import 'package:prueba01/features/provider_portal/provider_portal_providers.dart';

import '../../support/account_test_support.dart';
import '../../support/auth_test_support.dart' show enterField, tapAndSettle, usePhoneViewport;

/// PNG de 1x1 válido.
final _png = Uint8List.fromList(base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
));

class _FakePicker implements ProductImagePicker {
  var picks = 0;

  @override
  Future<PickedImage?> pick() async {
    picks++;
    return PickedImage(bytes: _png, extension: 'png', contentType: 'image/png');
  }
}

Future<RoleTestBed> _pumpPortal(WidgetTester tester, _FakePicker picker) async {
  usePhoneViewport(tester);
  final bed = RoleTestBed();
  await bed.store();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [...bed.overrides, productImagePickerProvider.overrideWithValue(picker)],
      retry: (retryCount, error) => null,
      child: const MaterialApp(home: MyOffersScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return bed;
}

Future<void> _fillOffer(WidgetTester tester, {String price = '2500000', String stock = '8'}) async {
  await tester.ensureVisible(find.widgetWithText(TextFormField, 'Ej. 2500000'));
  await enterField(tester, 'Ej. 2500000', price);
  await enterField(tester, 'Ej. 12', stock);
}

void main() {
  testWidgets('la tienda publica su oferta sobre un producto que ya existe', (tester) async {
    await _pumpPortal(tester, _FakePicker());
    expect(find.text('No tienes publicaciones con este estado.'), findsOneWidget);

    await tapAndSettle(tester, find.text('PUBLICAR UN PRODUCTO'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre, marca o modelo'), 'rtx 5090');
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pumpAndSettle();
    expect(find.text('NVIDIA GEFORCE RTX 5090'), findsOneWidget);

    await tapAndSettle(tester, find.text('Vender'));
    expect(find.text('PUBLICAR OFERTA'), findsOneWidget);
    await _fillOffer(tester);
    await tapAndSettle(tester, find.text('PUBLICAR'));

    expect(find.text('TU OFERTA'), findsOneWidget);
    expect(find.text('\$2.500.000'), findsOneWidget);
    expect(find.textContaining('La ficha es compartida'), findsOneWidget, reason: 'es del catálogo base');
    expect(find.text('EDITAR FICHA DEL PRODUCTO'), findsNothing);
  });

  testWidgets('registra un producto nuevo con su ficha, su imagen y su oferta', (tester) async {
    final picker = _FakePicker();
    await _pumpPortal(tester, picker);
    await tapAndSettle(tester, find.text('PUBLICAR UN PRODUCTO'));
    await tapAndSettle(tester, find.text('REGISTRAR PRODUCTO NUEVO'));

    await tapAndSettle(tester, find.widgetWithText(ChoiceChip, 'GPU'));
    await enterField(tester, 'Ej. NVIDIA GeForce RTX 5070 12 GB', 'ZZ Gráfica Nueva 12 GB');
    await enterField(tester, 'Ej. NVIDIA', 'ZZMarca');
    await enterField(tester, 'Ej. RTX 5070 (sirve para no duplicar productos)', 'ZZ-N1');
    await enterField(tester, 'Texto', 'ZZ 5070');
    final numbers = find.widgetWithText(TextFormField, 'Número');
    for (final (index, value) in [(0, '12'), (1, '220'), (2, '285')]) {
      await tester.ensureVisible(numbers.at(index));
      await tester.enterText(numbers.at(index), value);
    }

    await tapAndSettle(tester, find.textContaining('AGREGAR IMAGEN'));
    expect(picker.picks, 1);
    expect(find.text('AGREGAR IMAGEN (1/8)'), findsOneWidget);

    await _fillOffer(tester, price: '1.850.000', stock: '4');
    await tapAndSettle(tester, find.text('PUBLICAR PRODUCTO'));

    expect(find.text('PUBLICACIÓN'), findsOneWidget);
    expect(find.text('ZZ Gráfica Nueva 12 GB'), findsOneWidget);
    expect(find.text('\$1.850.000'), findsOneWidget);
    expect(find.text('EDITAR FICHA DEL PRODUCTO'), findsOneWidget, reason: 'la registró y nadie más la vende');
  });

  testWidgets('si el producto ya existe, ofrece publicar la oferta sobre él', (tester) async {
    await _pumpPortal(tester, _FakePicker());
    await tapAndSettle(tester, find.text('PUBLICAR UN PRODUCTO'));
    await tapAndSettle(tester, find.text('REGISTRAR PRODUCTO NUEVO'));
    await tapAndSettle(tester, find.widgetWithText(ChoiceChip, 'GPU'));
    // El mock usa el nombre del catálogo base como modelo.
    await enterField(tester, 'Ej. NVIDIA GeForce RTX 5070 12 GB', 'Mi RTX 5090');
    await enterField(tester, 'Ej. NVIDIA', 'NVIDIA');
    await enterField(tester, 'Ej. RTX 5070 (sirve para no duplicar productos)', 'NVIDIA GEFORCE RTX 5090');
    await enterField(tester, 'Texto', 'GB202');
    final numbers = find.widgetWithText(TextFormField, 'Número');
    for (final (index, value) in [(0, '32'), (1, '575'), (2, '304')]) {
      await tester.ensureVisible(numbers.at(index));
      await tester.enterText(numbers.at(index), value);
    }
    await tapAndSettle(tester, find.textContaining('AGREGAR IMAGEN'));
    await _fillOffer(tester);
    await tapAndSettle(tester, find.text('PUBLICAR PRODUCTO'));

    expect(find.text('Ya está en el catálogo'), findsOneWidget);
    await tapAndSettle(tester, find.text('Publicar mi oferta'));
    expect(find.text('PUBLICAR OFERTA'), findsOneWidget);
    expect(find.text('NVIDIA GEFORCE RTX 5090'), findsOneWidget);
  });

  testWidgets('retira una publicación y la puede volver a publicar', (tester) async {
    await _pumpPortal(tester, _FakePicker());
    await tapAndSettle(tester, find.text('PUBLICAR UN PRODUCTO'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre, marca o modelo'), 'kraken');
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.text('Vender'));
    await _fillOffer(tester);
    await tapAndSettle(tester, find.text('PUBLICAR'));

    await tapAndSettle(tester, find.text('RETIRAR PUBLICACIÓN'));
    await tapAndSettle(tester, find.text('Retirar'));
    expect(find.text('Publicación retirada.'), findsOneWidget);
    expect(find.text('VOLVER A PUBLICAR'), findsOneWidget);
    expect(find.text('Retirada'), findsOneWidget);
  });

  testWidgets('la tienda ve por qué NEXUS ocultó su publicación y pide la revisión', (tester) async {
    final bed = await _pumpPortal(tester, _FakePicker());
    await tapAndSettle(tester, find.text('PUBLICAR UN PRODUCTO'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre, marca o modelo'), 'kraken');
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.text('Vender'));
    await _fillOffer(tester);
    await tapAndSettle(tester, find.text('PUBLICAR'));

    // El administrador la oculta (en Supabase, admin_moderate_offer).
    final container = ProviderScope.containerOf(tester.element(find.byType(MyOffersScreen, skipOffstage: false)));
    final repository = container.read(providerPortalRepositoryProvider) as MockPortalRepository;
    final productId = (await repository.getMyOffers()).items.single.productId;
    final storeId = bed.directory.storeOf(bed.auth.currentUser!.id)!.id;
    repository.moderate(storeId, productId, OfferModeration.hidden, reason: 'Agrega fotos reales del producto');
    container.invalidate(myOfferDetailProvider(productId));
    await tester.pumpAndSettle();

    expect(find.text('OCULTA POR NEXUS'), findsOneWidget);
    expect(find.text('Motivo: Agrega fotos reales del producto'), findsOneWidget);
    expect(find.text('No visible'), findsOneWidget);

    await tapAndSettle(tester, find.text('YA LA CORREGÍ: SOLICITAR REVISIÓN'));
    expect(find.text('Listo: NEXUS revisará la publicación.'), findsOneWidget);
    expect(find.text('EN REVISIÓN'), findsOneWidget);
    expect(find.text('YA LA CORREGÍ: SOLICITAR REVISIÓN'), findsNothing, reason: 'se pide una sola vez');
  });

  testWidgets('el formulario de la oferta valida el descuento', (tester) async {
    await _pumpPortal(tester, _FakePicker());
    await tapAndSettle(tester, find.text('PUBLICAR UN PRODUCTO'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre, marca o modelo'), 'rtx 5090');
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.text('Vender'));

    await _fillOffer(tester);
    await enterField(tester, 'Déjalo vacío si no hay descuento', '2000000');
    await tapAndSettle(tester, find.text('PUBLICAR'));
    expect(find.text('Debe ser mayor que el precio actual.'), findsOneWidget);
    expect(find.text('PUBLICAR OFERTA'), findsOneWidget);
  });
}
