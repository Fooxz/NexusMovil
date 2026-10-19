/// Datos personales del cliente (RF-004).
class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
  });

  final String id;
  final String email;
  final String fullName;
  final String? phone;
}

/// Dirección de entrega guardada.
class Address {
  const Address({
    required this.id,
    required this.label,
    required this.recipientName,
    required this.phone,
    required this.department,
    required this.city,
    required this.addressLine,
    this.details,
    required this.isDefault,
  });

  final String id;
  final String label;
  final String recipientName;
  final String phone;
  final String department;
  final String city;
  final String addressLine;
  final String? details;
  final bool isDefault;

  /// Línea corta para listas: "Calle 10 # 20-30, Medellín (Antioquia)".
  String get summary => '$addressLine, $city ($department)';

  AddressInput toInput() => AddressInput(
    label: label,
    recipientName: recipientName,
    phone: phone,
    department: department,
    city: city,
    addressLine: addressLine,
    details: details,
    isDefault: isDefault,
  );
}

/// Datos para crear o editar una dirección.
class AddressInput {
  const AddressInput({
    required this.label,
    required this.recipientName,
    required this.phone,
    required this.department,
    required this.city,
    required this.addressLine,
    this.details,
    this.isDefault = false,
  });

  final String label;
  final String recipientName;
  final String phone;
  final String department;
  final String city;
  final String addressLine;
  final String? details;

  /// Pedir que sea la predeterminada. La primera dirección siempre lo es.
  final bool isDefault;
}

/// Departamentos de Colombia y Bogotá D. C. Supuesto S-02: una sola
/// jurisdicción de operación, por confirmar.
const colombianDepartments = [
  'Amazonas',
  'Antioquia',
  'Arauca',
  'Atlántico',
  'Bogotá D. C.',
  'Bolívar',
  'Boyacá',
  'Caldas',
  'Caquetá',
  'Casanare',
  'Cauca',
  'Cesar',
  'Chocó',
  'Córdoba',
  'Cundinamarca',
  'Guainía',
  'Guaviare',
  'Huila',
  'La Guajira',
  'Magdalena',
  'Meta',
  'Nariño',
  'Norte de Santander',
  'Putumayo',
  'Quindío',
  'Risaralda',
  'San Andrés y Providencia',
  'Santander',
  'Sucre',
  'Tolima',
  'Valle del Cauca',
  'Vaupés',
  'Vichada',
];
