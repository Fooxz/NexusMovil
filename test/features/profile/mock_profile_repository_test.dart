import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/core/errors/app_failure.dart';
import 'package:prueba01/features/profile/domain/profile_models.dart';

import '../../support/auth_test_support.dart';

AddressInput address(String label, {bool isDefault = false}) => AddressInput(
  label: label,
  recipientName: 'Ana Pérez',
  phone: '300 123 4567',
  department: 'Antioquia',
  city: 'Medellín',
  addressLine: 'Calle 10 # 20-30',
  isDefault: isDefault,
);

void main() {
  late AuthTestBed bed;

  setUp(() async {
    bed = AuthTestBed();
    await bed.registerAccount(keepSignedIn: true);
  });

  Future<List<String>> labels() async => [
    for (final address in await bed.profile.listAddresses())
      '${address.label}${address.isDefault ? '*' : ''}',
  ];

  test('the profile starts with the signup name and normalizes the phone', () async {
    expect((await bed.profile.getProfile()).fullName, 'Ana Pérez');

    final updated = await bed.profile.updateProfile(
      fullName: ' Ana María ',
      phone: '300 123-4567',
    );

    expect(updated.fullName, 'Ana María');
    expect(updated.phone, '3001234567');
  });

  test('keeps exactly one default address', () async {
    await bed.profile.createAddress(address('Casa'));
    await bed.profile.createAddress(address('Oficina'));
    expect(await labels(), ['Casa*', 'Oficina']);

    await bed.profile.createAddress(address('Finca', isDefault: true));
    expect(await labels(), ['Finca*', 'Casa', 'Oficina']);

    final finca = (await bed.profile.listAddresses()).first;
    await bed.profile.deleteAddress(finca.id);
    expect(await labels(), ['Oficina*', 'Casa']);
  });

  test('addresses belong to the signed-in user', () async {
    await bed.profile.createAddress(address('Casa'));
    await bed.auth.signOut();

    await expectLater(bed.profile.listAddresses(), throwsA(isA<UnauthorizedFailure>()));

    await bed.registerAccount(email: 'beto@nexus.test', keepSignedIn: true);
    expect(await bed.profile.listAddresses(), isEmpty);
  });
}
