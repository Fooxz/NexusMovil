/// Usuario con sesión iniciada.
class AuthUser {
  const AuthUser({required this.id, required this.email});

  final String id;
  final String email;

  @override
  bool operator ==(Object other) =>
      other is AuthUser && other.id == id && other.email == email;

  @override
  int get hashCode => Object.hash(id, email);
}

/// Versión vigente de un documento que el cliente acepta al registrarse
/// (RF-007): `terms` o `privacy`.
class LegalDocument {
  const LegalDocument({
    required this.code,
    required this.version,
    required this.title,
    required this.content,
  });

  final String code;
  final String version;
  final String title;
  final String content;
}

/// Resultado del registro.
enum SignUpResult {
  /// La cuenta quedó creada y con sesión iniciada.
  signedIn,

  /// La cuenta quedó creada, pero hay que confirmar el correo antes de entrar
  /// (cuando el proyecto exige confirmación).
  confirmationRequired,
}
