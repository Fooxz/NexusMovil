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

/// Piezas que se ven en el selector de una ranura: la búsqueda, el orden y
/// las páginas cargadas.
class CandidatesState {
  const CandidatesState({
    required this.items,
    this.search = '',
    this.cheapestFirst = true,
    this.hasMore = false,
    this.loadingMore = false,
    this.refreshing = false,
  });

  final List<BuilderCandidate> items;
  final String search;
  final bool cheapestFirst;

  /// La última página vino llena: puede haber más.
  final bool hasMore;
  final bool loadingMore;

  /// Cargando otra búsqueda u orden: se sigue mostrando la lista anterior.
  final bool refreshing;

  CandidatesState copyWith({
    List<BuilderCandidate>? items,
    bool? hasMore,
    bool? loadingMore,
    bool? refreshing,
  }) => CandidatesState(
    items: items ?? this.items,
    search: search,
    cheapestFirst: cheapestFirst,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
    refreshing: refreshing ?? this.refreshing,
  );
}

/// Piezas para una ranura, según la configuración actual (RF-049). Con un
/// catálogo grande se buscan, se ordenan por precio y se cargan por páginas.
/// Se recarga cuando cambia la selección, conservando la búsqueda y el orden.
final builderCandidatesProvider = AsyncNotifierProvider.autoDispose
    .family<CandidatesController, CandidatesState, ProductCategory>(
      CandidatesController.new,
    );

class CandidatesController extends AsyncNotifier<CandidatesState> {
  CandidatesController(this.category);

  final ProductCategory category;
  String _search = '';
  bool _cheapestFirst = true;
  int _page = 0;

  /// Cada carga invalida las anteriores: una respuesta lenta de una búsqueda
  /// vieja no pisa la nueva.
  int _generation = 0;

  List<String> get _offerIds =>
      ref.read(pcBuilderControllerProvider).value?.offerIds ?? const [];

  @override
  Future<CandidatesState> build() {
    // La clave de texto evita recargar si la selección no cambió.
    ref.watch(
      pcBuilderControllerProvider.select(
        (state) => state.value?.offerIds.join(',') ?? '',
      ),
    );
    ref.watch(pcBuilderRepositoryProvider);
    return _firstPage();
  }

  Future<CandidatesState> _firstPage() async {
    _page = 0;
    final items = await ref
        .read(pcBuilderRepositoryProvider)
        .candidates(
          category,
          _offerIds,
          search: _search,
          cheapestFirst: _cheapestFirst,
        );
    return CandidatesState(
      items: items,
      search: _search,
      cheapestFirst: _cheapestFirst,
      hasMore: items.length >= PcBuilderRepository.candidatesPageSize,
    );
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    if (state.value case final current?) {
      state = AsyncData(current.copyWith(refreshing: true));
    }
    try {
      final next = await _firstPage();
      if (generation == _generation) state = AsyncData(next);
    } catch (error, stackTrace) {
      if (generation == _generation) state = AsyncError(error, stackTrace);
    }
  }

  Future<void> setSearch(String search) {
    if (search.trim() == _search) return Future.value();
    _search = search.trim();
    return _reload();
  }

  Future<void> setCheapestFirst(bool cheapestFirst) {
    if (cheapestFirst == _cheapestFirst) return Future.value();
    _cheapestFirst = cheapestFirst;
    return _reload();
  }

  /// Agrega la página siguiente. Si falla, se conserva lo que había y el
  /// error se lanza para mostrarlo.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    final generation = _generation;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await ref
          .read(pcBuilderRepositoryProvider)
          .candidates(
            category,
            _offerIds,
            search: _search,
            cheapestFirst: _cheapestFirst,
            page: _page + 1,
          );
      if (generation != _generation) return;
      _page++;
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...next],
          hasMore: next.length >= PcBuilderRepository.candidatesPageSize,
          loadingMore: false,
        ),
      );
    } catch (_) {
      if (generation == _generation) {
        state = AsyncData(current.copyWith(loadingMore: false));
      }
      rethrow;
    }
  }
}


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

/// Escena lista para el visor: dónde va cada pieza y cuáles están marcadas
/// por una incompatibilidad. Se calcula aquí y no en `build` (R3). Mientras
/// recarga conserva la escena anterior.
final viewerSceneProvider = Provider.autoDispose<AsyncValue<ViewerScene>>((
  ref,
) {
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
