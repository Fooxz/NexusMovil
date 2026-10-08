String formatPrice(int cents) {
  final absoluteCents = cents.abs();
  final wholePart = (absoluteCents ~/ 100).toString();
  final groupedWholePart = StringBuffer();

  for (var index = 0; index < wholePart.length; index++) {
    if (index > 0 && (wholePart.length - index) % 3 == 0) {
      groupedWholePart.write(',');
    }
    groupedWholePart.write(wholePart[index]);
  }

  final sign = cents < 0 ? '-' : '';
  final fractionalPart = (absoluteCents % 100).toString().padLeft(2, '0');
  return '$sign\$$groupedWholePart.$fractionalPart';
}
