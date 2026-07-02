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
}
