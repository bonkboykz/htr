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

  /// Session history (newest first). Active session has endedAt == null.
  Future<List<SessionSummary>> sessions() async {
    final json = await _api.get('/api/v1/training/sessions');
    return (json as List)
        .map((e) => SessionSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SessionDetail> sessionDetail(String id) async {
    final json = await _api.get('/api/v1/training/sessions/$id');
    return SessionDetail.fromJson(json as Map<String, dynamic>);
  }

  /// Exercise catalog — used to look up per-exercise weight increments.
  Future<List<Exercise>> exercises() async {
    final json = await _api.get('/api/v1/training/exercises');
    return (json as List)
        .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateSet(
    String sessionId,
    String setId, {
    int? weightG,
    int? reps,
    int? rir,
  }) async {
    final body = <String, dynamic>{};
    if (weightG != null) body['weight_g'] = weightG;
    if (reps != null) body['reps'] = reps;
    if (rir != null) body['rir'] = rir;
    await _api.patch(
      '/api/v1/training/sessions/$sessionId/sets/$setId',
      body: body,
    );
  }

  Future<void> deleteSet(String sessionId, String setId) async {
    await _api.delete('/api/v1/training/sessions/$sessionId/sets/$setId');
  }

  Future<void> deleteSession(String id) async {
    await _api.delete('/api/v1/training/sessions/$id');
  }
}
