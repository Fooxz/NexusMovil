import '../../catalog/domain/product.dart';
import 'build_scene.dart';
import 'pc_builder_models.dart';

/// Armador de PC (HU-008). La compatibilidad la decide el motor de reglas del
/// backend (RN-013): la app nunca la calcula. Errores como `AppFailure`.
abstract class PcBuilderRepository {
  Future<List<BuilderSlot>> getSlots();

  /// Evalúa la configuración formada por [offerIds] (una oferta por ranura).
  Future<BuildValidation> validate(List<String> offerIds);

  /// Piezas de [category] para la configuración [offerIds]: primero las
  /// compatibles y con stock, luego por precio.
  Future<List<BuilderCandidate>> candidates(
    ProductCategory category,
    List<String> offerIds,
  );

  /// Modelos 3D y atributos visuales de las piezas [offerIds] (RF-090).
  Future<BuildScene> scene(List<String> offerIds);

  /// Componentes del computador armado [productId] por sección, para verlo
  /// en 3D.
  Future<PrebuiltScene> prebuiltScene(String productId);
}
