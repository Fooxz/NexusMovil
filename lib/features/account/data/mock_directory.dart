import '../domain/account_models.dart';

/// Tienda en memoria, con los datos que ve el administrador.
class MockStore {
  MockStore({
    required this.id,
    required this.legalName,
    required this.displayName,
    required this.taxId,
    required this.contactEmail,
    this.status = StoreStatus.active,
    this.userId,
    this.verificationNote,
  });

  final String id;
  String legalName;
  String displayName;
  String taxId;
  String contactEmail;
  StoreStatus status;
  String? userId;
  String? verificationNote;

  StoreSummary get summary =>
      StoreSummary(id: id, displayName: displayName, status: status);
}

/// Roles y tiendas en memoria para usar la app sin backend. Lo comparten los
/// mocks de cuenta, publicaciones y administración, como en Supabase lo
/// comparten las tablas `profiles` y `providers`.
class MockDirectory {
  /// Empieza con las tiendas del catálogo de prueba (`MockProductRepository`),
  /// sin cuenta, como las que se cargaron antes de los roles.
  MockDirectory() {
    for (final (id, name, taxId) in const [
      ('prov-tecnopartes', 'TecnoPartes', '900111222-1'),
      ('prov-mundopc', 'Mundo PC', '900333444-2'),
      ('prov-demo', 'Tienda demo', '900999000-9'),
    ]) {
      stores[id] = MockStore(
        id: id,
        legalName: '$name S.A.S.',
        displayName: name,
        taxId: taxId,
        contactEmail: 'ventas@${id.substring(5)}.example',
      );
    }
  }

  final roles = <String, AccountRole>{};

  /// Por id de tienda.
  final stores = <String, MockStore>{};

  /// Cuentas creadas por un administrador: contraseña temporal y documentos
  /// pendientes hasta el primer ingreso.
  final provisioned = <String>{};

  /// Cuentas creadas por un administrador que ya aceptaron los documentos.
  final acceptedDocuments = <String>{};

  MockStore? storeOf(String userId) {
    for (final store in stores.values) {
      if (store.userId == userId) return store;
    }
    return null;
  }

  /// Tienda activa de la cuenta, si ya completó el primer ingreso.
  MockStore? readyStoreOf(String userId, {required bool passwordChanged}) {
    final store = storeOf(userId);
    if (store == null || roles[userId] != AccountRole.provider) return null;
    if (store.status != StoreStatus.active) return null;
    if (provisioned.contains(userId) &&
        (!passwordChanged || !acceptedDocuments.contains(userId))) {
      return null;
    }
    return store;
  }
}
