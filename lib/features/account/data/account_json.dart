import '../domain/account_models.dart';

/// Lectura de `get_my_account` (API_CONTRATO, parte 7). Lanza
/// `FormatException` si falta un campo obligatorio. Un rol desconocido se lee
/// como cliente: es el que menos puede hacer.
Account accountFromJson(Object? json) {
  if (json case {
    'userId': String userId,
    'role': String roleName,
    'mustChangePassword': bool mustChangePassword,
    'pendingDocuments': List<Object?> pending,
  }) {
    return Account(
      userId: userId,
      role: AccountRole.values.asNameMap()[roleName] ?? AccountRole.customer,
      fullName: json['fullName'] is String ? json['fullName'] as String : null,
      mustChangePassword: mustChangePassword,
      pendingDocuments: [
        for (final document in pending)
          if (document case {
            'code': String code,
            'version': String version,
            'title': String title,
          })
            PendingDocument(code: code, version: version, title: title),
      ],
      store: storeSummaryFromJson(json['provider']),
    );
  }
  throw FormatException('Cuenta inválida', json);
}

/// `{id, displayName, status}` de una tienda, o null.
StoreSummary? storeSummaryFromJson(Object? json) {
  if (json case {
    'id': String id,
    'displayName': String displayName,
    'status': String status,
  }) {
    return StoreSummary(
      id: id,
      displayName: displayName,
      status: storeStatusFromName(status),
    );
  }
  return null;
}

/// Un estado desconocido se lee como suspendida: no puede operar.
StoreStatus storeStatusFromName(String name) =>
    StoreStatus.values.asNameMap()[name] ?? StoreStatus.suspended;
