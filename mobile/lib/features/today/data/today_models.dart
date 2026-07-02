// Plain models for the "Сегодня" screen. Manual `fromJson` (qmeta pattern).
// Integer domain fields stay raw; we display the API's `*Formatted` strings.

class CaloriesBudget {
  final int consumedCalories;
  final int targetCalories;
  final int remainingCalories;
  final String remainingCaloriesFormatted;
  final int progress; // 0-100

  const CaloriesBudget({
    required this.consumedCalories,
    required this.targetCalories,
    required this.remainingCalories,
    required this.remainingCaloriesFormatted,
    required this.progress,
  });

  factory CaloriesBudget.fromJson(Map<String, dynamic> json) => CaloriesBudget(
        consumedCalories: (json['consumedCalories'] as num?)?.toInt() ?? 0,
        targetCalories: (json['targetCalories'] as num?)?.toInt() ?? 0,
        remainingCalories: (json['remainingCalories'] as num?)?.toInt() ?? 0,
        remainingCaloriesFormatted:
            (json['remainingCaloriesFormatted'] ?? '').toString(),
        progress: (json['progress'] as num?)?.toInt() ?? 0,
      );
}

class NutritionTotals {
  final int calories;
  final int protein;
  final int fat;
  final int carbs;
  final String caloriesFormatted;
  final String proteinFormatted;
  final String fatFormatted;
  final String carbsFormatted;

  const NutritionTotals({
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.caloriesFormatted,
    required this.proteinFormatted,
    required this.fatFormatted,
    required this.carbsFormatted,
  });

  factory NutritionTotals.fromJson(Map<String, dynamic> json) => NutritionTotals(
        calories: (json['calories'] as num?)?.toInt() ?? 0,
        protein: (json['protein'] as num?)?.toInt() ?? 0,
        fat: (json['fat'] as num?)?.toInt() ?? 0,
        carbs: (json['carbs'] as num?)?.toInt() ?? 0,
        caloriesFormatted: (json['caloriesFormatted'] ?? '').toString(),
        proteinFormatted: (json['proteinFormatted'] ?? '').toString(),
        fatFormatted: (json['fatFormatted'] ?? '').toString(),
        carbsFormatted: (json['carbsFormatted'] ?? '').toString(),
      );
}

class WaterSummary {
  final int totalMl;
  final String totalFormatted;
  final int targetMl;
  final String targetFormatted;
  final int progress;

  const WaterSummary({
    required this.totalMl,
    required this.totalFormatted,
    required this.targetMl,
    required this.targetFormatted,
    required this.progress,
  });

  factory WaterSummary.fromJson(Map<String, dynamic> json) => WaterSummary(
        totalMl: (json['totalMl'] as num?)?.toInt() ?? 0,
        totalFormatted: (json['totalFormatted'] ?? '').toString(),
        targetMl: (json['targetMl'] as num?)?.toInt() ?? 0,
        targetFormatted: (json['targetFormatted'] ?? '').toString(),
        progress: (json['progress'] as num?)?.toInt() ?? 0,
      );
}

class SleepSummary {
  final int totalMinutes;
  final String totalFormatted;
  final int targetMinutes;
  final int progress;

  const SleepSummary({
    required this.totalMinutes,
    required this.totalFormatted,
    required this.targetMinutes,
    required this.progress,
  });

  factory SleepSummary.fromJson(Map<String, dynamic> json) => SleepSummary(
        totalMinutes: (json['totalMinutes'] as num?)?.toInt() ?? 0,
        totalFormatted: (json['totalFormatted'] ?? '').toString(),
        targetMinutes: (json['targetMinutes'] as num?)?.toInt() ?? 0,
        progress: (json['progress'] as num?)?.toInt() ?? 0,
      );
}

class WeightSummary {
  final int weightGrams;
  final String weightFormatted;

  const WeightSummary({
    required this.weightGrams,
    required this.weightFormatted,
  });

  factory WeightSummary.fromJson(Map<String, dynamic> json) => WeightSummary(
        weightGrams: (json['weightGrams'] as num?)?.toInt() ?? 0,
        weightFormatted: (json['weightFormatted'] ?? '').toString(),
      );
}

class DailySummary {
  final CaloriesBudget? caloriesBudget;
  final NutritionTotals nutrition;
  final WaterSummary water;
  final SleepSummary sleep;
  final WeightSummary? weight;

  const DailySummary({
    required this.caloriesBudget,
    required this.nutrition,
    required this.water,
    required this.sleep,
    required this.weight,
  });

  factory DailySummary.fromJson(Map<String, dynamic> json) {
    final budget = json['caloriesBudget'];
    final nutrition = (json['nutrition'] as Map?)?['totals'];
    final weight = json['weight'];
    return DailySummary(
      caloriesBudget: budget is Map
          ? CaloriesBudget.fromJson(budget.cast<String, dynamic>())
          : null,
      nutrition: nutrition is Map
          ? NutritionTotals.fromJson(nutrition.cast<String, dynamic>())
          : const NutritionTotals(
              calories: 0,
              protein: 0,
              fat: 0,
              carbs: 0,
              caloriesFormatted: '',
              proteinFormatted: '',
              fatFormatted: '',
              carbsFormatted: '',
            ),
      water: WaterSummary.fromJson(
          (json['water'] as Map?)?.cast<String, dynamic>() ?? const {}),
      sleep: SleepSummary.fromJson(
          (json['sleep'] as Map?)?.cast<String, dynamic>() ?? const {}),
      weight: weight is Map
          ? WeightSummary.fromJson(weight.cast<String, dynamic>())
          : null,
    );
  }
}

class TrainingToday {
  final String? routineId;
  final int? sessionIndex;
  final bool isRampup;

  const TrainingToday({
    required this.routineId,
    required this.sessionIndex,
    required this.isRampup,
  });

  factory TrainingToday.fromJson(Map<String, dynamic> json) => TrainingToday(
        routineId: json['routine_id']?.toString(),
        sessionIndex: (json['session_index'] as num?)?.toInt(),
        isRampup: json['is_rampup'] == true,
      );

  /// "routine-a" → "A", "routine-b" → "B".
  String get routineLabel {
    final id = routineId ?? '';
    if (id.endsWith('-a')) return 'A';
    if (id.endsWith('-b')) return 'B';
    final parts = id.split('-');
    return parts.isNotEmpty ? parts.last.toUpperCase() : '';
  }
}

/// Bundle returned by the repository: daily summary + (optional) training.
class TodayData {
  final DailySummary summary;
  final TrainingToday? training;

  const TodayData({required this.summary, required this.training});
}
