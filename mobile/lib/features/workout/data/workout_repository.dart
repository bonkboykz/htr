import '../../../core/network/api_client.dart';
import 'workout_models.dart';

/// Talks to the training API. Constructed from `sl<ApiClient>()` in the page.
class WorkoutRepository {
  final ApiClient _api;
  WorkoutRepository(this._api);

  Future<TrainingToday> today() async {
    final json = await _api.get('/api/v1/training/today');
    return TrainingToday.fromJson(json as Map<String, dynamic>);
  }

  Future<WorkoutPlan> plan(String routineId, int sessionIndex) async {
    final json = await _api.get(
      '/api/v1/training/routines/$routineId/plan',
      query: {'sessionIndex': sessionIndex},
    );
    return WorkoutPlan.fromJson(json as Map<String, dynamic>);
  }

  Future<SessionStart> startSession(String routineId, int sessionIndex) async {
    final json = await _api.post(
      '/api/v1/training/sessions',
      body: {'routine_id': routineId, 'session_index': sessionIndex},
    );
    return SessionStart.fromJson(json as Map<String, dynamic>);
  }

  Future<String> logSet(
    String sessionId, {
    required String exerciseId,
    required int setNumber,
    required int weightG,
    required int reps,
    required int? rir,
    required bool isWarmup,
  }) async {
    final json = await _api.post(
      '/api/v1/training/sessions/$sessionId/sets',
      body: {
        'exercise_id': exerciseId,
        'set_number': setNumber,
        'weight_g': weightG,
        'reps': reps,
        'rir': rir,
        'is_warmup': isWarmup,
      },
    );
    return (json as Map<String, dynamic>)['set_id'].toString();
  }

  Future<int> finish(String sessionId) async {
    final json = await _api.patch(
      '/api/v1/training/sessions/$sessionId',
      body: <String, dynamic>{},
    );
    return ((json as Map<String, dynamic>)['duration_s'] as num?)?.toInt() ?? 0;
  }
}
