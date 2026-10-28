import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_rpc.dart';
import '../domain/account_models.dart';
import '../domain/account_repository.dart';
import 'account_json.dart';

/// Cuenta con sesión: RPC `get_my_account` y `accept_current_documents`.
class SupabaseAccountRepository implements AccountRepository {
  SupabaseAccountRepository(this._rpc);

  factory SupabaseAccountRepository.fromClient(SupabaseClient client) =>
      SupabaseAccountRepository(supabaseRpc(client));

  final SupabaseRpc _rpc;

  @override
  Future<Account> getMyAccount() async {
    final json = await guardedRpc(_rpc, 'get_my_account');
    return parseResponse(() => accountFromJson(json));
  }

  @override
  Future<Account> acceptDocuments(List<PendingDocument> documents) async {
    final json = await guardedRpc(_rpc, 'accept_current_documents', {
      'documents': [
        for (final document in documents)
          {'code': document.code, 'version': document.version},
      ],
    });
    return parseResponse(() => accountFromJson(json));
  }
}
