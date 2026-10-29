/// Tipos de documento para la facturación en Colombia (RF-056).
enum DocumentType {
  cc('CC', 'Cédula de ciudadanía'),
  ce('CE', 'Cédula de extranjería'),
  nit('NIT', 'NIT'),
  pp('PP', 'Pasaporte'),
  ti('TI', 'Tarjeta de identidad');

  const DocumentType(this.code, this.label);

  final String code;
  final String label;
}

/// Contacto y datos de facturación del comprador.
class CheckoutContact {
  const CheckoutContact({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.documentType,
    required this.documentNumber,
  });

  final String fullName;
  final String email;
  final String phone;
  final DocumentType documentType;
  final String documentNumber;

  Map<String, Object> toJson() => {
    'fullName': fullName.trim(),
    'email': email.trim(),
    'phone': phone,
    'documentType': documentType.code,
    'documentNumber': documentNumber.trim(),
  };
}

/// Intento de pago creado en el backend, listo para abrir en Mercado Pago.
class CheckoutSession {
  const CheckoutSession({
    required this.reference,
    required this.amountCents,
    required this.checkoutUrl,
    required this.redirectUrl,
    required this.expiresAt,
  });

  final String reference;
  final int amountCents;

  /// Checkout Pro de Mercado Pago: la preferencia la crea el backend.
  final Uri checkoutUrl;

  /// A dónde vuelve Mercado Pago al terminar, con `?payment_id=<pago>`. La
  /// app la intercepta en lugar de abrirla.
  final Uri redirectUrl;
  final DateTime expiresAt;

  /// [url] es la página de regreso de este pago.
  bool isReturnUrl(Uri url) =>
      url.scheme == redirectUrl.scheme &&
      url.host == redirectUrl.host &&
      url.port == redirectUrl.port &&
      url.path == redirectUrl.path;
}

enum PaymentStatus {
  /// Esperando a la pasarela (por ejemplo, PSE o Nequi sin confirmar).
  pending,
  approved,
  declined,
  voided,
  error,

  /// El cliente empezó otro intento sin pagar este.
  abandoned;

  static PaymentStatus fromJson(Object? value) => switch (value) {
    'pending' => pending,
    'approved' => approved,
    'declined' => declined,
    'voided' => voided,
    'error' => error,
    'abandoned' => abandoned,
    _ => throw FormatException('Estado de pago desconocido: $value'),
  };

  /// La pasarela no cobró: se puede reintentar.
  bool get isRejected => this == declined || this == voided || this == error;
}

class PlacedOrderItem {
  const PlacedOrderItem({
    required this.productId,
    required this.productName,
    required this.brand,
    required this.quantity,
    required this.unitPriceCents,
    required this.lineTotalCents,
    this.backorderedUnits = 0,
  });

  final String productId;
  final String productName;
  final String brand;
  final int quantity;
  final int unitPriceCents;
  final int lineTotalCents;

  /// Unidades que ya no había al aprobarse el pago: el proveedor las resuelve.
  final int backorderedUnits;
}

/// Lo que despacha un proveedor (S-06).
class PlacedSubOrder {
  const PlacedSubOrder({
    required this.id,
    required this.providerName,
    required this.subtotalCents,
    required this.items,
  });

  final String id;
  final String providerName;
  final int subtotalCents;
  final List<PlacedOrderItem> items;
}

/// Orden creada con el pago aprobado (RN-025).
class PlacedOrder {
  const PlacedOrder({
    required this.id,
    required this.number,
    required this.totalCents,
    required this.createdAt,
    required this.subOrders,
  });

  final String id;

  /// Número para el cliente, por ejemplo `NX-000123`.
  final String number;
  final int totalCents;
  final DateTime createdAt;
  final List<PlacedSubOrder> subOrders;

  bool get hasBackorders => subOrders.any(
    (subOrder) => subOrder.items.any((item) => item.backorderedUnits > 0),
  );
}

/// Estado de un intento de pago, con la orden si ya se aprobó.
class CheckoutStatus {
  const CheckoutStatus({
    required this.reference,
    required this.status,
    required this.amountCents,
    this.transactionId,
    this.paymentMethod,
    this.message,
    this.order,
  });

  final String reference;
  final PaymentStatus status;
  final int amountCents;

  /// `null` mientras la pasarela no informe una transacción: el cliente no
  /// llegó a pagar o el aviso aún no llega.
  final String? transactionId;

  /// `CARD`, `NEQUI`, `PSE`...
  final String? paymentMethod;
  final String? message;
  final PlacedOrder? order;
}
