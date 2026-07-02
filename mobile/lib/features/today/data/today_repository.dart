import '../../../core/network/api_client.dart';
import 'today_models.dart';

/// Loads the "Сегодня" screen data. The daily summary is required; the training
/// fetch is best-effort (tolerate failure → null).
class TodayRepository {
  final ApiClient _api;
  TodayRepository(this._api);

  Future<TodayData> load(String date) async {
    final daily = await _api.get('/api/v1/daily/$date');
    final summary = DailySummary.fromJson((daily as Map).cast<String, dynamic>());

    TrainingToday? training;
    try {
      final t = await _api.get('/api/v1/training/today');
      if (t is Map) {
        training = TrainingToday.fromJson(t.cast<String, dynamic>());
      }
    } catch (_) {
      training = null; // training endpoint is optional
    }

    return TodayData(summary: summary, training: training);
  }
}
