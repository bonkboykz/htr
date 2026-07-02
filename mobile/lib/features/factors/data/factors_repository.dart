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

  /// All factor categories (for picking one when creating a factor).
  Future<List<FactorCategory>> loadCategories() async {
    final json = await _api.get('/api/v1/factor-categories');
    return (json as List<dynamic>)
        .map((e) => FactorCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Create a custom factor. Body is camelCase; only non-null fields are sent.
  Future<Factor> createFactor({
    required String categoryId,
    required String name,
    String kind = 'rating',
    int? scaleMin,
    int? scaleMax,
    String? unit,
    Map<String, String>? labels,
  }) async {
    final body = <String, dynamic>{
      'categoryId': categoryId,
      'name': name,
      'kind': kind,
    };
    if (scaleMin != null) body['scaleMin'] = scaleMin;
    if (scaleMax != null) body['scaleMax'] = scaleMax;
    if (unit != null && unit.isNotEmpty) body['unit'] = unit;
    if (labels != null && labels.isNotEmpty) body['labels'] = labels;
    final json = await _api.post('/api/v1/factors', body: body);
    return Factor.fromJson(json as Map<String, dynamic>);
  }

  /// Soft-delete a factor.
  Future<void> deleteFactor(String id) async {
    await _api.delete('/api/v1/factors/$id');
  }

  /// Create a factor category.
  Future<FactorCategory> createCategory({
    required String name,
    String? emoji,
  }) async {
    final body = <String, dynamic>{'name': name};
    if (emoji != null && emoji.isNotEmpty) body['emoji'] = emoji;
    final json = await _api.post('/api/v1/factor-categories', body: body);
    return FactorCategory.fromJson(json as Map<String, dynamic>);
  }
}
