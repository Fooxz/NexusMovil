import '../../account/domain/account_models.dart';

/// Una tienda vista por el administrador (API_CONTRATO, parte 7).
class AdminStore {
  const AdminStore({
    required this.id,
    required this.legalName,
    required this.displayName,
    required this.taxId,
    required this.contactEmail,
    required this.status,
    this.verificationNote,
    this.accountEmail,
    this.publishedOffers = 0,
  });

  final String id;
  final String legalName;

  /// El nombre que ven los clientes en cada tarjeta.
  final String displayName;
  final String taxId;
  final String contactEmail;
  final StoreStatus status;
  final String? verificationNote;

  /// Correo de la cuenta que opera la tienda; null si todavía no tiene.
  final String? accountEmail;
  final int publishedOffers;

  bool get hasAccount => accountEmail != null;

  StoreInput toInput() => StoreInput(
    legalName: legalName,
    displayName: displayName,
    taxId: taxId,
    contactEmail: contactEmail,
    verificationNote: verificationNote,
  );
}

/// Datos de una tienda verificada por el administrador.
class StoreInput {
  const StoreInput({
    required this.legalName,
    required this.displayName,
    required this.taxId,
    required this.contactEmail,
    this.verificationNote,
  });

  final String legalName;
  final String displayName;
  final String taxId;
  final String contactEmail;

  /// Cómo se verificó que la tienda existe (visita, documentos...).
  final String? verificationNote;

  Map<String, Object?> toJson() => {
    'legalName': legalName.trim(),
    'displayName': displayName.trim(),
    'taxId': taxId.trim(),
    'contactEmail': contactEmail.trim(),
    if (verificationNote != null && verificationNote!.trim().isNotEmpty)
      'verificationNote': verificationNote!.trim(),
  };
}

/// Cuenta que operará la tienda.
class NewAccountInput {
  const NewAccountInput({required this.email, required this.fullName});

  final String email;
  final String fullName;

  Map<String, Object?> toJson() => {'email': email.trim(), 'fullName': fullName.trim()};
}

/// Resultado del alta o de regenerar la contraseña. [temporaryPassword] se
/// muestra una sola vez al administrador: NEXUS no la guarda.
class ProvisionResult {
  const ProvisionResult({required this.store, required this.temporaryPassword});

  final AdminStore store;
  final String temporaryPassword;
}
