import '../../../core/network/api_client.dart';
import 'program_models.dart';

/// Talks to the training API for the read-first Program screen.
/// Constructed from `sl<ApiClient>()` in the page.
class ProgramRepository {
  final ApiClient _api;
  ProgramRepository(this._api);

  Future<List<Routine>> routines() async {
    final json = await _api.get('/api/v1/training/routines');
    return (json as List)
        .map((e) => Routine.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Exercise catalog keyed by id — used to resolve names for positions.
  Future<Map<String, ProgramCatalogExercise>> exercisesById() async {
    final json = await _api.get('/api/v1/training/exercises');
    final list = (json as List)
        .map((e) => ProgramCatalogExercise.fromJson(e as Map<String, dynamic>))
        .toList();
    return {for (final e in list) e.id: e};
  }

  Future<List<ProgramExercise>> routineExercises(String routineId) async {
    final json =
        await _api.get('/api/v1/training/routines/$routineId/exercises');
    return (json as List)
        .map((e) => ProgramExercise.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---------- mutations (snake_case bodies) ----------

  Future<Routine> createRoutine({
    required String name,
    required String nameRu,
    String? notes,
    int? sortOrder,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'name_ru': nameRu,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (sortOrder != null) 'sort_order': sortOrder,
    };
    final json = await _api.post('/api/v1/training/routines', body: body);
    return Routine.fromJson(json as Map<String, dynamic>);
  }

  Future<Routine> updateRoutine(
    String id, {
    String? name,
    String? nameRu,
    String? notes,
  }) async {
    final body = <String, dynamic>{
      if (name != null) 'name': name,
      if (nameRu != null) 'name_ru': nameRu,
      if (notes != null) 'notes': notes,
    };
    final json =
        await _api.patch('/api/v1/training/routines/$id', body: body);
    return Routine.fromJson(json as Map<String, dynamic>);
  }

  Future<void> deleteRoutine(String id) async {
    await _api.delete('/api/v1/training/routines/$id');
  }

  Future<ProgramExercise> addExercise(
    String routineId, {
    required String exerciseId,
    required String section,
    int? sortOrder,
    required int targetSets,
    required int repMin,
    required int repMax,
    int? targetRir,
    String? notes,
  }) async {
    final body = <String, dynamic>{
      'exercise_id': exerciseId,
      'section': section,
      if (sortOrder != null) 'sort_order': sortOrder,
      'target_sets': targetSets,
      'rep_min': repMin,
      'rep_max': repMax,
      if (targetRir != null) 'target_rir': targetRir,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };
    final json = await _api
        .post('/api/v1/training/routines/$routineId/exercises', body: body);
    return ProgramExercise.fromJson(json as Map<String, dynamic>);
  }

  Future<ProgramExercise> updateExercise(
    String routineId,
    String reId, {
    String? exerciseId,
    String? section,
    int? sortOrder,
    int? targetSets,
    int? repMin,
    int? repMax,
    int? targetRir,
    String? notes,
  }) async {
    final body = <String, dynamic>{
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (section != null) 'section': section,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (targetSets != null) 'target_sets': targetSets,
      if (repMin != null) 'rep_min': repMin,
      if (repMax != null) 'rep_max': repMax,
      if (targetRir != null) 'target_rir': targetRir,
      if (notes != null) 'notes': notes,
    };
    final json = await _api.patch(
        '/api/v1/training/routines/$routineId/exercises/$reId',
        body: body);
    return ProgramExercise.fromJson(json as Map<String, dynamic>);
  }

  Future<void> deleteExercise(String routineId, String reId) async {
    await _api.delete('/api/v1/training/routines/$routineId/exercises/$reId');
  }
}
