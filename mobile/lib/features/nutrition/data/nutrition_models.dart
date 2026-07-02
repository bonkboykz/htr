// Plain models for the "Питание" screen. Manual `fromJson` (qmeta pattern).
// Integer domain fields stay raw (calories = kcal, macros = tenths of grams);
// we display the API's `*Formatted` strings or derive integer grams for the UI.

class FoodEntry {
  final String id;
  final String mealId;
  final String foodItemId;
  final int servingGrams;
  final int calories; // kcal
  final int protein; // tenths of grams
  final int fat; // tenths of grams
  final int carbs; // tenths of grams
  final String caloriesFormatted;

  /// Enriched from the foods list (entries carry only `foodItemId`).
  final String name;

  const FoodEntry({
    required this.id,
    required this.mealId,
    required this.foodItemId,
    required this.servingGrams,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.caloriesFormatted,
    required this.name,
  });

  factory FoodEntry.fromJson(Map<String, dynamic> json, String name) => FoodEntry(
        id: (json['id'] ?? '').toString(),
        mealId: (json['mealId'] ?? '').toString(),
        foodItemId: (json['foodItemId'] ?? '').toString(),
        servingGrams: (json['servingGrams'] as num?)?.toInt() ?? 0,
        calories: (json['calories'] as num?)?.toInt() ?? 0,
        protein: (json['protein'] as num?)?.toInt() ?? 0,
        fat: (json['fat'] as num?)?.toInt() ?? 0,
        carbs: (json['carbs'] as num?)?.toInt() ?? 0,
        caloriesFormatted: (json['caloriesFormatted'] ?? '').toString(),
        name: name,
      );

  int get proteinG => (protein / 10).round();
  int get fatG => (fat / 10).round();
  int get carbsG => (carbs / 10).round();
}

class MealGroup {
  final String mealId;
  final String mealName; // raw name from API (English seed)
  final List<FoodEntry> entries;

  const MealGroup({
    required this.mealId,
    required this.mealName,
    required this.entries,
  });

  int get totalCalories => entries.fold(0, (sum, e) => sum + e.calories);
}

class NutritionTotals {
  final int calories;
  final int protein; // tenths of grams
  final int fat;
  final int carbs;

  const NutritionTotals({
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
  });

  factory NutritionTotals.fromJson(Map<String, dynamic> json) => NutritionTotals(
        calories: (json['calories'] as num?)?.toInt() ?? 0,
        protein: (json['protein'] as num?)?.toInt() ?? 0,
        fat: (json['fat'] as num?)?.toInt() ?? 0,
        carbs: (json['carbs'] as num?)?.toInt() ?? 0,
      );

  int get proteinG => (protein / 10).round();
  int get fatG => (fat / 10).round();
  int get carbsG => (carbs / 10).round();
}

class NutritionTarget {
  final int calories;
  final int protein; // tenths of grams
  final int fat;
  final int carbs;

  const NutritionTarget({
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
  });

  factory NutritionTarget.fromJson(Map<String, dynamic> json) => NutritionTarget(
        calories: (json['calories'] as num?)?.toInt() ?? 0,
        protein: (json['protein'] as num?)?.toInt() ?? 0,
        fat: (json['fat'] as num?)?.toInt() ?? 0,
        carbs: (json['carbs'] as num?)?.toInt() ?? 0,
      );

  int get proteinG => (protein / 10).round();
  int get fatG => (fat / 10).round();
  int get carbsG => (carbs / 10).round();
}

class NutritionDay {
  final String date;
  final List<MealGroup> meals;
  final NutritionTotals totals;
  final NutritionTarget? target;

  const NutritionDay({
    required this.date,
    required this.meals,
    required this.totals,
    required this.target,
  });

  int get consumedCalories => totals.calories;
  int? get remainingCalories =>
      target == null ? null : target!.calories - totals.calories;
}

/// Payload for a quick-log request. Macros are entered in whole grams by the
/// user; the repository converts them to tenths of grams for the API.
class QuickLogInput {
  final String mealId;
  final String name;
  final int calories;
  final int? proteinG;
  final int? fatG;
  final int? carbsG;

  const QuickLogInput({
    required this.mealId,
    required this.name,
    required this.calories,
    this.proteinG,
    this.fatG,
    this.carbsG,
  });
}
