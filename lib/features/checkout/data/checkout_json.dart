import '../domain/checkout_models.dart';

/// Lectura de las respuestas de la función `checkout` (API_CONTRATO, parte 5).
/// Lanzan `FormatException` si falta un campo obligatorio.

CheckoutSession checkoutSessionFromJson(Object? json) {
  if (json case {
    'reference': String reference,
    'amountCents': int amountCents,
    'checkoutUrl': String checkoutUrl,
    'redirectUrl': String redirectUrl,
    'expiresAt': String expiresAt,
  }) {
    return CheckoutSession(
      reference: reference,
      amountCents: amountCents,
      checkoutUrl: Uri.parse(checkoutUrl),
      redirectUrl: Uri.parse(redirectUrl),
      expiresAt: DateTime.parse(expiresAt),
    );
  }
  throw FormatException('Intento de pago inválido', json);
}

CheckoutStatus checkoutStatusFromJson(Object? json) {
  if (json case {
    'reference': String reference,
    'status': String status,
    'amountCents': int amountCents,
  }) {
    final order = json['order'];
    return CheckoutStatus(
      reference: reference,
      status: PaymentStatus.fromJson(status),
      amountCents: amountCents,
      transactionId: _string(json['transactionId']),
      paymentMethod: _string(json['paymentMethod']),
      message: _string(json['message']),
      order: order == null ? null : _orderFromJson(order),
    );
  }
  throw FormatException('Estado de pago inválido', json);
}

String? _string(Object? value) => value is String ? value : null;

PlacedOrder _orderFromJson(Object? json) {
  if (json case {
    'id': String id,
    'number': String number,
    'totalCents': int totalCents,
    'createdAt': String createdAt,
    'subOrders': List<Object?> subOrders,
  }) {
    return PlacedOrder(
      id: id,
      number: number,
      totalCents: totalCents,
      createdAt: DateTime.parse(createdAt),
      subOrders: [for (final subOrder in subOrders) _subOrderFromJson(subOrder)],
    );
  }
  throw FormatException('Orden inválida', json);
}

PlacedSubOrder _subOrderFromJson(Object? json) {
  if (json case {
    'id': String id,
    'providerName': String providerName,
    'subtotalCents': int subtotalCents,
    'items': List<Object?> items,
  }) {
    return PlacedSubOrder(
      id: id,
      providerName: providerName,
      subtotalCents: subtotalCents,
      items: [for (final item in items) _itemFromJson(item)],
    );
  }
  throw FormatException('Sub-orden inválida', json);
}

PlacedOrderItem _itemFromJson(Object? json) {
  if (json case {
    'productId': String productId,
    'productName': String productName,
    'brand': String brand,
    'quantity': int quantity,
    'unitPriceCents': int unitPriceCents,
    'lineTotalCents': int lineTotalCents,
  }) {
    final backordered = json['backorderedUnits'];
    return PlacedOrderItem(
      productId: productId,
      productName: productName,
      brand: brand,
      quantity: quantity,
      unitPriceCents: unitPriceCents,
      lineTotalCents: lineTotalCents,
      backorderedUnits: backordered is int ? backordered : 0,
    );
  }
  throw FormatException('Ítem de orden inválido', json);
}
