import '../../../core/network/api_client.dart';
import 'nutrition_models.dart';

/// Loads and mutates the "Питание" screen data.
///
/// Food-log entries carry only a `foodItemId` (no name), so we fetch the foods
/// list once and build an id → name map to enrich the entries for display.
class NutritionRepository {
  final ApiClient _api;
  NutritionRepository(this._api);

  Future<NutritionDay> load(String date) async {
    final nameById = await _foodNames();

    final json = await _api.get('/api/v1/food-logs', query: {'date': date});
    final map = (json as Map).cast<String, dynamic>();

    final meals = <MealGroup>[];
    for (final m in (map['meals'] as List? ?? const [])) {
      final mm = (m as Map).cast<String, dynamic>();
      final meal = (mm['meal'] as Map?)?.cast<String, dynamic>() ?? const {};
      final mealId = (meal['id'] ?? '').toString();
      final mealName = (meal['name'] ?? '').toString();
      final entries = <FoodEntry>[];
      for (final e in (mm['entries'] as List? ?? const [])) {
        final em = (e as Map).cast<String, dynamic>();
        final foodItemId = (em['foodItemId'] ?? '').toString();
        entries.add(FoodEntry.fromJson(
          em,
          nameById[foodItemId] ?? 'Продукт',
        ));
      }
      meals.add(MealGroup(mealId: mealId, mealName: mealName, entries: entries));
    }

    final totals = NutritionTotals.fromJson(
      (map['totals'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final targetJson = map['target'];
    final target = targetJson is Map
        ? NutritionTarget.fromJson(targetJson.cast<String, dynamic>())
        : null;

    return NutritionDay(
      date: (map['date'] ?? date).toString(),
      meals: meals,
      totals: totals,
      target: target,
    );
  }

  Future<Map<String, String>> _foodNames() async {
    try {
      final list = await _api.get('/api/v1/foods');
      final out = <String, String>{};
      if (list is List) {
        for (final f in list) {
          if (f is Map) {
            final id = (f['id'] ?? '').toString();
            final name = (f['name'] ?? '').toString();
            if (id.isNotEmpty) out[id] = name;
          }
        }
      }
      return out;
    } catch (_) {
      return const {}; // best-effort; entries fall back to "Продукт"
    }
  }

  Future<void> quickLog(String date, QuickLogInput input) async {
    await _api.post('/api/v1/food-logs/quick', body: {
      'date': date,
      'mealId': input.mealId,
      'name': input.name,
      'calories': input.calories,
      if (input.proteinG != null) 'protein': input.proteinG! * 10,
      if (input.fatG != null) 'fat': input.fatG! * 10,
      if (input.carbsG != null) 'carbs': input.carbsG! * 10,
    });
  }

  Future<void> deleteEntry(String id) async {
    await _api.delete('/api/v1/food-logs/$id');
  }
}
