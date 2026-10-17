import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/core/utils/format_price.dart';

void main() {
  test('formats zero pesos', () {
    expect(formatPrice(0), '\$0');
  });

  test('formats prices below one thousand pesos', () {
    expect(formatPrice(99900), '\$999');
  });

  test('groups thousands with dots', () {
    expect(formatPrice(100000), '\$1.000');
  });

  test('groups millions with dots', () {
    expect(formatPrice(919600000), '\$9.196.000');
  });

  test('rounds centavos to the nearest peso', () {
    expect(formatPrice(150), '\$2');
  });
}
