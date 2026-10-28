import '../../account/data/account_json.dart';
import '../domain/admin_models.dart';

/// Lectura de `admin_provider_json` (API_CONTRATO, parte 7). Lanza
/// `FormatException` si falta un campo obligatorio.
AdminStore adminStoreFromJson(Object? json) {
  if (json case {
    'id': String id,
    'legalName': String legalName,
    'displayName': String displayName,
    'taxId': String taxId,
    'contactEmail': String contactEmail,
    'status': String status,
  }) {
    return AdminStore(
      id: id,
      legalName: legalName,
      displayName: displayName,
      taxId: taxId,
      contactEmail: contactEmail,
      status: storeStatusFromName(status),
      verificationNote: json['verificationNote'] is String ? json['verificationNote'] as String : null,
      accountEmail: json['accountEmail'] is String ? json['accountEmail'] as String : null,
      publishedOffers: json['publishedOffers'] is int ? json['publishedOffers'] as int : 0,
    );
  }
  throw FormatException('Tienda inválida', json);
}

/// Respuesta de la Edge Function: `{provider, temporaryPassword}`.
ProvisionResult provisionResultFromJson(Object? json) {
  if (json case {'provider': final Object provider, 'temporaryPassword': String password}) {
    return ProvisionResult(store: adminStoreFromJson(provider), temporaryPassword: password);
  }
  throw const FormatException('Respuesta del alta inválida');
}
