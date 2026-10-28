import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/app_failure.dart';

/// Llama a una RPC de Supabase y devuelve el JSON ya decodificado. Las
/// pruebas la reemplazan por una función falsa.
typedef SupabaseRpc =
    Future<Object?> Function(String function, Map<String, Object?> params);

SupabaseRpc supabaseRpc(SupabaseClient client) =>
    (function, params) => client.rpc<Object?>(function, params: params);

/// Ejecuta la RPC y traduce los errores de Supabase y de red a `AppFailure`.
Future<Object?> guardedRpc(
  SupabaseRpc rpc,
  String function, [
  Map<String, Object?> params = const {},
]) async {
  try {
    return await rpc(function, params);
  } on PostgrestException catch (error) {
    throw AppFailure.fromApiError(
      code: error.code,
      details: error.details,
      message: error.message,
    );
  } on AppFailure {
    rethrow;
  } on Exception {
    // Sin respuesta del servidor: ClientException, SocketException, timeout.
    throw const NetworkFailure();
  }
}

/// Convierte la respuesta en objetos; un JSON con otra forma es un error
/// inesperado, no un fallo de la app.
T parseResponse<T>(T Function() parse) {
  try {
    return parse();
  } on FormatException {
    throw const UnexpectedFailure();
  }
}
