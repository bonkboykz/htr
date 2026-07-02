import '../../../core/network/api_client.dart';
import 'progress_models.dart';

/// Talks to the stats + training analytics API. Constructed from
/// `sl<ApiClient>()` in the page.
class ProgressRepository {
  final ApiClient _api;
  ProgressRepository(this._api);

  Future<WeightTrend> weightTrend(ProgressRange range) async {
    final json = await _api.get(
      '/api/v1/stats/weight-trend',
      query: {'days': range.days},
    );
    return WeightTrend.fromJson(json as Map<String, dynamic>);
  }

  Future<Progression> progression(String exerciseId, ProgressRange range) async {
    final json = await _api.get(
      '/api/v1/training/progression/$exerciseId',
      query: {'range': range.apiRange},
    );
    return Progression.fromJson(json as Map<String, dynamic>);
  }

  Future<VolumeStats> volume(ProgressRange range) async {
    final json = await _api.get(
      '/api/v1/training/stats/volume',
      query: {'range': range.apiRange},
    );
    return VolumeStats.fromJson(json as Map<String, dynamic>);
  }

  /// Load everything for a range + selected lift concurrently.
  Future<ProgressData> load(ProgressRange range, String exerciseId) async {
    final results = await Future.wait([
      weightTrend(range),
      progression(exerciseId, range),
      volume(range),
    ]);
    return ProgressData(
      weight: results[0] as WeightTrend,
      progression: results[1] as Progression,
      volume: results[2] as VolumeStats,
    );
  }
}
