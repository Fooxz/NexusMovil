import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../routes.dart';
import '../auth_providers.dart';

/// Para acciones que exigen sesión (RN-027): si no hay sesión abre el login
/// y espera. Devuelve `true` si al final hay una sesión iniciada.
///
/// [reason] completa "Inicia sesión ...", por ejemplo
/// `'para confirmar tu pedido'`.
Future<bool> ensureSignedIn(
  BuildContext context,
  WidgetRef ref, {
  String? reason,
}) async {
  // Se consulta el repositorio y no `currentUserProvider`: justo después de
  // iniciar sesión el aviso del stream puede no haber llegado todavía.
  final repository = ref.read(authRepositoryProvider);
  if (repository.currentUser != null) return true;
  final result = await Navigator.of(
    context,
  ).pushNamed<bool>(NexusRoutes.login, arguments: reason);
  return result == true && repository.currentUser != null;
}
