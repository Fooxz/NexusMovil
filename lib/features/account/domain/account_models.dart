/// Roles de NEXUS (API_CONTRATO, parte 7). Son exclusivos: solo los clientes
/// compran, las tiendas publican y los administradores habilitan tiendas. El
/// backend valida el rol en cada función; la app solo lo usa para elegir la
/// navegación.
enum AccountRole { customer, provider, admin }

/// Estado de una tienda. Solo las activas publican y venden (RN-022).
/// Suspendida es temporal; bloqueada, por incumplir las políticas;
/// desactivada, dejó de operar.
enum StoreStatus { pending, active, suspended, blocked, deactivated, rejected }

/// La tienda que opera una cuenta de proveedor.
class StoreSummary {
  const StoreSummary({
    required this.id,
    required this.displayName,
    required this.status,
  });

  final String id;
  final String displayName;
  final StoreStatus status;
}

/// Versión vigente de un documento legal que la cuenta todavía no aceptó.
class PendingDocument {
  const PendingDocument({
    required this.code,
    required this.version,
    required this.title,
  });

  final String code;
  final String version;
  final String title;
}

/// Cuenta con sesión, tal como la informa el backend (`get_my_account`).
class Account {
  const Account({
    required this.userId,
    required this.role,
    this.fullName,
    this.mustChangePassword = false,
    this.pendingDocuments = const [],
    this.store,
  });

  final String userId;
  final AccountRole role;
  final String? fullName;

  /// La contraseña es temporal (la generó un administrador).
  final bool mustChangePassword;
  final List<PendingDocument> pendingDocuments;

  /// Solo en las cuentas de tienda.
  final StoreSummary? store;

  bool get canBuy => role == AccountRole.customer;

  /// Una tienda debe cambiar su contraseña temporal y aceptar los documentos
  /// vigentes antes de publicar; el backend también lo exige.
  bool get needsStoreSetup =>
      role == AccountRole.provider &&
      (mustChangePassword || pendingDocuments.isNotEmpty);
}
