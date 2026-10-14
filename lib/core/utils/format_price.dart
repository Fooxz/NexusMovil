String formatPrice(int cents) {
  final sign = cents < 0 ? '-' : '';
  final absoluteCents = cents.abs();
  final wholePart = ((absoluteCents + 50) ~/ 100).toString();
  final groupedWholePart = StringBuffer();

  for (var index = 0; index < wholePart.length; index++) {
    if (index > 0 && (wholePart.length - index) % 3 == 0) {
      groupedWholePart.write('.');
    }
    groupedWholePart.write(wholePart[index]);
  }

  return '$sign\$$groupedWholePart';
}
