import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/network/supabase_rpc.dart';
import '../../account/domain/account_models.dart';
import '../domain/admin_models.dart';
import '../domain/admin_repository.dart';
import 'admin_json.dart';

/// Llama a la Edge Function `admin-providers` con la sesión del
/// administrador y devuelve el cuerpo de la respuesta.
typedef AdminFunctionCall = Future<Object?> Function(Map<String, Object?> body);

/// Administración de tiendas: RPC `admin_*` y la Edge Function
/// `admin-providers`. La app nunca tiene la clave de servicio.
class SupabaseAdminRepository implements AdminRepository {
  SupabaseAdminRepository(this._rpc, this._function);

  factory SupabaseAdminRepository.fromClient(SupabaseClient client) => SupabaseAdminRepository(
    supabaseRpc(client),
    (body) async => (await client.functions.invoke('admin-providers', body: body)).data,
  );

  final SupabaseRpc _rpc;
  final AdminFunctionCall _function;

  Future<AdminStore> _store(String function, Map<String, Object?> params) async {
    final json = await guardedRpc(_rpc, function, params);
    return parseResponse(() => adminStoreFromJson(json));
  }

  Future<ProvisionResult> _provision(Map<String, Object?> body) async {
    final Object? json;
    try {
      json = await _function(body);
    } on FunctionException catch (error) {
      // El cuerpo de error del contrato: {code, message, details}.
      final details = error.details;
      throw details is Map
          ? AppFailure.fromApiError(
              statusCode: error.status,
              code: details['code'] as String?,
              details: details['details'],
              message: details['message'] as String?,
            )
          : AppFailure.fromApiError(statusCode: error.status);
    } on AppFailure {
      rethrow;
    } on Exception {
      throw const NetworkFailure();
    }
    return parseResponse(() => provisionResultFromJson(json));
  }

  @override
  Future<List<AdminStore>> getStores({String search = ''}) async {
    final json = await guardedRpc(_rpc, 'admin_get_providers', {
      if (search.trim().isNotEmpty) 'search': search.trim(),
    });
    return parseResponse(() {
      if (json is! List<Object?>) throw FormatException('Lista de tiendas inválida', json);
      return [for (final store in json) adminStoreFromJson(store)];
    });
  }

  @override
  Future<AdminStore> getStore(String id) => _store('admin_get_provider', {'id': id});

  @override
  Future<AdminStore> setStoreStatus(String id, StoreStatus status) =>
      _store('admin_set_provider_status', {'id': id, 'status': status.name});

  @override
  Future<AdminStore> updateStore(String id, StoreInput store, {bool confirmSimilarName = false}) =>
      _store('admin_update_provider', {
        'id': id,
        'store': store.toJson(),
        'confirm_similar_name': confirmSimilarName,
      });

  @override
  Future<ProvisionResult> createStore(
    StoreInput store,
    NewAccountInput account, {
    bool confirmSimilarName = false,
  }) => _provision({
    'action': 'create_provider',
    'store': store.toJson(),
    'account': account.toJson(),
    'confirmSimilarName': confirmSimilarName,
  });

  @override
  Future<ProvisionResult> createAccount(String storeId, NewAccountInput account) =>
      _provision({'action': 'create_account', 'providerId': storeId, 'account': account.toJson()});

  @override
  Future<ProvisionResult> resetPassword(String storeId) =>
      _provision({'action': 'reset_password', 'providerId': storeId});
}
