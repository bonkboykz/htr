import '../../../core/network/api_client.dart';
import 'insights_models.dart';

/// Fetches auto-detected insights for a date range.
class InsightsRepository {
  final ApiClient _api;
  InsightsRepository(this._api);

  Future<List<Insight>> load(String from, String to) async {
    final json = await _api.get(
      '/api/v1/correlations/insights',
      query: {'from': from, 'to': to},
    );
    final map = json as Map<String, dynamic>;
    final list = (map['insights'] as List?) ?? const [];
    return list
        .map((e) => Insight.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }
}
