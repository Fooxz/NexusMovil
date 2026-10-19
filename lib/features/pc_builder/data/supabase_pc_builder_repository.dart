import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../catalog/data/supabase_product_repository.dart' show RpcCall;
import '../../catalog/domain/product.dart';
import '../domain/build_scene.dart';
import '../domain/pc_builder_models.dart';
import '../domain/pc_builder_repository.dart';
import 'build_scene_json.dart';
import 'pc_builder_json.dart';

/// Bucket público de Storage con los archivos .glb (fase 6.1).
const componentModelsBucket = 'component-models';

/// Armador con las RPC de docs/API_CONTRATO.md, parte 3.
class SupabasePcBuilderRepository implements PcBuilderRepository {
  SupabasePcBuilderRepository(this._rpc, {String Function(String path)? modelUrl})
    : _modelUrl = modelUrl ?? ((path) => path);

  factory SupabasePcBuilderRepository.fromClient(SupabaseClient client) =>
      SupabasePcBuilderRepository(
        (function, params) => client.rpc<Object?>(function, params: params),
        modelUrl: client.storage.from(componentModelsBucket).getPublicUrl,
      );

  final RpcCall _rpc;

  /// Dirección pública de un archivo del bucket de modelos.
  final String Function(String path) _modelUrl;

  @override
  Future<List<BuilderSlot>> getSlots() =>
      _call('get_builder_slots', const {}, builderSlotsFromJson);

  @override
  Future<BuildValidation> validate(List<String> offerIds) =>
      _call('validate_build', {'offer_ids': offerIds}, buildValidationFromJson);

  @override
  Future<List<BuilderCandidate>> candidates(
    ProductCategory category,
    List<String> offerIds,
  ) => _call('get_builder_candidates', {
    'category': category.name,
    'offer_ids': offerIds,
  }, builderCandidatesFromJson);

  @override
  Future<BuildScene> scene(List<String> offerIds) => _call(
    'get_build_scene',
    {'offer_ids': offerIds},
    (json) => buildSceneFromJson(json, modelUrl: _modelUrl),
  );

  @override
  Future<PrebuiltScene> prebuiltScene(String productId) => _call(
    'get_prebuilt_scene',
    {'product_id': productId},
    (json) => prebuiltSceneFromJson(json, modelUrl: _modelUrl),
  );

  Future<T> _call<T>(
    String function,
    Map<String, Object?> params,
    T Function(Object?) parse,
  ) async {
    final Object? json;
    try {
      json = await _rpc(function, params);
    } on PostgrestException catch (error) {
      throw AppFailure.fromApiError(code: error.code, details: error.details);
    } on AppFailure {
      rethrow;
    } on Exception {
      throw const NetworkFailure();
    }
    try {
      return parse(json);
    } on FormatException {
      throw const UnexpectedFailure();
    }
  }
}
