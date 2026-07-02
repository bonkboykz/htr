import '../../../core/network/api_client.dart';
import 'factors_models.dart';

class FactorsRepository {
  final ApiClient _api;
  FactorsRepository(this._api);

  /// Factor logs for a date, grouped by category.
  Future<List<FactorGroup>> load(String date) async {
    final json = await _api.get('/api/v1/factor-logs', query: {'date': date});
    return (json as List<dynamic>)
        .map((e) => FactorGroup.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Upsert many factor values at once.
  Future<void> saveBulk(String date, Map<String, int> values) async {
    final entries = values.entries
        .map((e) => {'factorId': e.key, 'value': e.value})
        .toList();
    await _api.post(
      '/api/v1/factor-logs/bulk',
      body: {'date': date, 'entries': entries},
    );
  }
}
