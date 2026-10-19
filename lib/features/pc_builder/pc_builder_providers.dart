import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/supabase_providers.dart';
import '../catalog/catalog_providers.dart';
import '../catalog/data/mock_product_repository.dart';
import '../catalog/domain/product.dart';
import 'data/mock_pc_builder_repository.dart';
import 'data/supabase_pc_builder_repository.dart';
import 'domain/build_scene.dart';
import 'domain/pc_builder_models.dart';
import 'domain/pc_builder_repository.dart';
import 'presentation/viewer/scene_layout.dart';

/// Con el mock del catálogo usa el mock del armador (que no verifica
/// compatibilidad y lo avisa); si no, el motor de reglas del backend.
final pcBuilderRepositoryProvider = Provider<PcBuilderRepository>((ref) {
  final products = ref.watch(productRepositoryProvider);
  if (products is MockProductRepository) {
    return MockPcBuilderRepository(products);
  }
  return SupabasePcBuilderRepository.fromClient(
    ref.watch(supabaseClientProvider),
  );
});

final builderSlotsProvider = FutureProvider<List<BuilderSlot>>(
  (ref) => ref.watch(pcBuilderRepositoryProvider).getSlots(),
);

/// Configuración en curso: qué oferta hay en cada ranura y su evaluación.
class BuilderState {
  BuilderState({
    required Map<ProductCategory, String> selection,
    required this.validation,
  }) : selection = Map.unmodifiable(selection);

  final Map<ProductCategory, String> selection;
  final BuildValidation validation;

  List<String> get offerIds => selection.values.toList(growable: false);

  bool get isEmpty => selection.isEmpty;
}

/// La configuración vive fuera del árbol de widgets y se conserva al cambiar
/// de pestaña mientras la app está abierta.
final pcBuilderControllerProvider =
    AsyncNotifierProvider<PcBuilderController, BuilderState>(
      PcBuilderController.new,
    );

class PcBuilderController extends AsyncNotifier<BuilderState> {
  Future<void> _queue = Future.value();

  PcBuilderRepository get _repository => ref.read(pcBuilderRepositoryProvider);

  @override
  Future<BuilderState> build() async {
    final repository = ref.watch(pcBuilderRepositoryProvider);
    return BuilderState(
      selection: const {},
      validation: await repository.validate(const []),
    );
  }

  Map<ProductCategory, String> get _selection =>
      state.value?.selection ?? const {};

  /// Pone [offerId] en la ranura [category] (reemplaza la que hubiera).
  Future<void> select(ProductCategory category, String offerId) =>
      _apply(() => {..._selection, category: offerId});

  Future<void> remove(ProductCategory category) => _apply(
    () => {
      for (final entry in _selection.entries)
        if (entry.key != category) entry.key: entry.value,
    },
  );

  Future<void> clear() => _apply(() => const {});

  /// Reemplaza la configuración por [offerIds], por ejemplo la que propuso el
  /// asistente (RF-089). Las ranuras salen de la validación del motor.
  Future<void> loadBuild(List<String> offerIds) {
    final run = _queue.then((_) async {
      final validation = await _repository.validate(offerIds);
      state = AsyncData(
        BuilderState(
          selection: {for (final part in validation.parts) part.category: part.offerId},
          validation: validation,
        ),
      );
    });
    _queue = run.then<void>((_) {}, onError: (_) {});
    return run;
  }

  /// Reevalúa con el motor de reglas. Si falla, la configuración anterior se
  /// conserva y el error llega a quien llamó.
  Future<void> _apply(Map<ProductCategory, String> Function() next) {
    final run = _queue.then((_) async {
      final selection = next();
      final validation = await _repository.validate(
        selection.values.toList(growable: false),
      );
      state = AsyncData(
        BuilderState(selection: selection, validation: validation),
      );
    });
    _queue = run.then<void>((_) {}, onError: (_) {});
    return run;
  }
}

/// Piezas para una ranura, según la configuración actual (RF-049). Se recarga
/// cuando cambia la selección.
final builderCandidatesProvider = FutureProvider.autoDispose
    .family<List<BuilderCandidate>, ProductCategory>((ref, category) {
      // La clave de texto evita recargar si la selección no cambió.
      ref.watch(
        pcBuilderControllerProvider.select(
          (state) => state.value?.offerIds.join(',') ?? '',
        ),
      );
      final offerIds =
          ref.read(pcBuilderControllerProvider).value?.offerIds ?? const [];
      return ref
          .watch(pcBuilderRepositoryProvider)
          .candidates(category, offerIds);
    });

/// Modelos y atributos visuales de la configuración actual (RF-090). Se
/// recarga cuando cambia la selección.
final buildSceneProvider = FutureProvider.autoDispose<BuildScene>((ref) {
  ref.watch(
    pcBuilderControllerProvider.select(
      (state) => state.value?.offerIds.join(',') ?? '',
    ),
  );
  final offerIds =
      ref.read(pcBuilderControllerProvider).value?.offerIds ?? const [];
  return ref.watch(pcBuilderRepositoryProvider).scene(offerIds);
});

/// Computador armado que se está viendo en el PC Builder ("Visualizar en
/// 3D"), o nulo. Es una vista aparte: no toca la configuración del cliente,
/// que vuelve al cerrarla.
final prebuiltPreviewProvider =
    NotifierProvider<PrebuiltPreviewController, String?>(
      PrebuiltPreviewController.new,
    );

class PrebuiltPreviewController extends Notifier<String?> {
  @override
  String? build() => null;

  void show(String productId) => state = productId;

  void close() => state = null;
}

/// Componentes del armado [productId] por sección.
final prebuiltSceneProvider = FutureProvider.autoDispose
    .family<PrebuiltScene, String>(
      (ref, productId) =>
          ref.watch(pcBuilderRepositoryProvider).prebuiltScene(productId),
    );

/// Escena lista para el visor: dónde va cada pieza y cuáles están marcadas
/// por una incompatibilidad. Se calcula aquí y no en `build` (R3). Mientras
/// recarga conserva la escena anterior. Con un armado en vista, muestra el
/// armado.
final viewerSceneProvider = Provider.autoDispose<AsyncValue<ViewerScene>>((
  ref,
) {
  final preview = ref.watch(prebuiltPreviewProvider);
  if (preview != null) {
    return ref
        .watch(prebuiltSceneProvider(preview))
        .whenData((prebuilt) => layoutScene(prebuilt.scene));
  }
  // Texto ordenado: un Set nuevo en cada evaluación no sería igual al anterior.
  final errorKey = ref.watch(
    pcBuilderControllerProvider.select((state) {
      final ids = {
        for (final issue in state.value?.validation.errors ?? const <BuildIssue>[])
          ...issue.offerIds,
      }.toList()..sort();
      return ids.join(',');
    }),
  );
  final errorOfferIds = errorKey.isEmpty ? <String>{} : errorKey.split(',').toSet();
  return ref
      .watch(buildSceneProvider)
      .whenData((scene) => layoutScene(scene, errorOfferIds: errorOfferIds));
});
