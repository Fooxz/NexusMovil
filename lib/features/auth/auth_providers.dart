import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/supabase_providers.dart';
import 'data/mock_auth_repository.dart';
import 'data/supabase_auth_repository.dart';
import 'domain/auth_models.dart';
import 'domain/auth_repository.dart';

/// Único punto que decide entre Supabase Auth y el mock.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (ref.watch(appEnvProvider).hasSupabase) {
    return SupabaseAuthRepository(ref.watch(supabaseClientProvider));
  }
  return MockAuthRepository();
});

final authStateProvider = StreamProvider<AuthUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// Usuario con sesión, o `null`, para que los widgets se reconstruyan al
/// cambiar la sesión. La fuente es el repositorio (que la conoce de forma
/// sincrónica); el stream solo avisa cuándo recalcular.
final currentUserProvider = Provider<AuthUser?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(authRepositoryProvider).currentUser;
});

final legalDocumentsProvider = FutureProvider.autoDispose<List<LegalDocument>>(
  (ref) => ref.watch(authRepositoryProvider).getCurrentLegalDocuments(),
);

// --- Acciones de formulario ---------------------------------------------
// Cada pantalla observa el estado de su acción: `loading` bloquea el botón y
// `error` muestra el mensaje del `AppFailure`.

final signInControllerProvider =
    AsyncNotifierProvider.autoDispose<SignInController, void>(
      SignInController.new,
    );

class SignInController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<bool> submit({required String email, required String password}) =>
      _run(
        state: (value) => state = value,
        action: () => ref
            .read(authRepositoryProvider)
            .signIn(email: email, password: password),
      );
}

final signUpControllerProvider =
    AsyncNotifierProvider.autoDispose<SignUpController, SignUpResult?>(
      SignUpController.new,
    );

class SignUpController extends AsyncNotifier<SignUpResult?> {
  @override
  FutureOr<SignUpResult?> build() => null;

  Future<SignUpResult?> submit({
    required String fullName,
    required String email,
    required String password,
    required List<LegalDocument> acceptedDocuments,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .signUp(
            fullName: fullName,
            email: email,
            password: password,
            acceptedDocuments: acceptedDocuments,
          ),
    );
    return state.value;
  }
}

/// Recuperación en dos pasos: pedir el código y luego usarlo.
final passwordResetControllerProvider =
    AsyncNotifierProvider.autoDispose<PasswordResetController, void>(
      PasswordResetController.new,
    );

class PasswordResetController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<bool> requestCode(String email) => _run(
    state: (value) => state = value,
    action: () => ref.read(authRepositoryProvider).requestPasswordReset(email),
  );

  Future<bool> reset({
    required String email,
    required String code,
    required String newPassword,
  }) => _run(
    state: (value) => state = value,
    action: () => ref
        .read(authRepositoryProvider)
        .resetPassword(email: email, code: code, newPassword: newPassword),
  );
}

Future<bool> _run({
  required void Function(AsyncValue<void>) state,
  required Future<void> Function() action,
}) async {
  state(const AsyncLoading());
  final result = await AsyncValue.guard(action);
  state(result);
  return !result.hasError;
}
