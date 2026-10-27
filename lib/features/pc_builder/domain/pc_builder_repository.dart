import '../../catalog/domain/product.dart';
import 'build_scene.dart';
import 'pc_builder_models.dart';

/// Armador de PC (HU-008). La compatibilidad la decide el motor de reglas del
/// backend (RN-013): la app nunca la calcula. Errores como `AppFailure`.
abstract class PcBuilderRepository {
  Future<List<BuilderSlot>> getSlots();

  /// Evalúa la configuración formada por [offerIds] (una oferta por ranura).
  Future<BuildValidation> validate(List<String> offerIds);

  /// Piezas por página de [candidates].
  static const candidatesPageSize = 30;

  /// Piezas de [category] para la configuración [offerIds]: primero las
  /// compatibles y con stock, luego por precio (de menor a mayor si
  /// [cheapestFirst]). [search] filtra por nombre o marca; [page] empieza en 0
  /// y trae hasta [candidatesPageSize] piezas.
  Future<List<BuilderCandidate>> candidates(
    ProductCategory category,
    List<String> offerIds, {
    String search = '',
    bool cheapestFirst = true,
    int page = 0,
  });

  /// Modelos 3D y atributos visuales de las piezas [offerIds] (RF-090).
  Future<BuildScene> scene(List<String> offerIds);
}
