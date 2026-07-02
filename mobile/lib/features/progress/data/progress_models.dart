import 'package:equatable/equatable.dart';

/// Selected range for the whole Progress screen.
enum ProgressRange { week, month, year }

extension ProgressRangeX on ProgressRange {
  /// Label for the segmented control.
  String get label => switch (this) {
        ProgressRange.week => 'Неделя',
        ProgressRange.month => 'Месяц',
        ProgressRange.year => 'Год',
      };

  /// Short suffix for change badges ("1.2 кг / 30 дн").
  String get periodLabel => switch (this) {
        ProgressRange.week => '7 дн',
        ProgressRange.month => '30 дн',
        ProgressRange.year => 'год',
      };

  /// Suffix for the volume card header ("Объём по группам · месяц").
  String get sectionLabel => switch (this) {
        ProgressRange.week => 'неделя',
        ProgressRange.month => 'месяц',
        ProgressRange.year => 'год',
      };

  /// `?days=` value for the weight-trend endpoint.
  int get days => switch (this) {
        ProgressRange.week => 7,
        ProgressRange.month => 30,
        ProgressRange.year => 365,
      };

  /// `?range=` value for the training endpoints. `year` falls back to
  /// all-time on the API (resolveRange only knows week/month).
  String get apiRange => switch (this) {
        ProgressRange.week => 'week',
        ProgressRange.month => 'month',
        ProgressRange.year => 'year',
      };
}

/// A single weight measurement (GET /stats/weight-trend → entries[]).
class WeightPoint extends Equatable {
  final String date; // YYYY-MM-DD
  final int weightGrams;
  final String weightFormatted;

  const WeightPoint({
    required this.date,
    required this.weightGrams,
    required this.weightFormatted,
  });

  factory WeightPoint.fromJson(Map<String, dynamic> j) => WeightPoint(
        date: (j['date'] ?? '').toString(),
        weightGrams: (j['weightGrams'] as num?)?.toInt() ?? 0,
        weightFormatted: (j['weightFormatted'] ?? '').toString(),
      );

  @override
  List<Object?> get props => [date, weightGrams, weightFormatted];
}

/// GET /api/v1/stats/weight-trend?days=
class WeightTrend extends Equatable {
  final List<WeightPoint> entries;
  final int trendGrams;
  final String trendFormatted;
  final int changeGrams;
  final String changeFormatted;

  const WeightTrend({
    required this.entries,
    required this.trendGrams,
    required this.trendFormatted,
    required this.changeGrams,
    required this.changeFormatted,
  });

  factory WeightTrend.fromJson(Map<String, dynamic> j) => WeightTrend(
        // API returns entries newest-first; sort ascending so the chart reads
        // oldest→newest left-to-right and `entries.last` is the current weight.
        entries: (((j['entries'] as List?) ?? const [])
            .map((e) => WeightPoint.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date))),
        trendGrams: (j['trendGrams'] as num?)?.toInt() ?? 0,
        trendFormatted: (j['trendFormatted'] ?? '').toString(),
        changeGrams: (j['changeGrams'] as num?)?.toInt() ?? 0,
        changeFormatted: (j['changeFormatted'] ?? '').toString(),
      );

  bool get hasData => entries.isNotEmpty;

  /// Latest formatted weight (falls back to the EMA trend).
  String get currentFormatted =>
      entries.isNotEmpty ? entries.last.weightFormatted : trendFormatted;

  @override
  List<Object?> get props =>
      [entries, trendGrams, trendFormatted, changeGrams, changeFormatted];
}

/// A single e1RM data point (GET /training/progression/:id → points[]).
class E1rmPoint extends Equatable {
  final String date;
  final int weightG;
  final int reps;
  final int e1rmG;
  final String e1rmFormatted;

  const E1rmPoint({
    required this.date,
    required this.weightG,
    required this.reps,
    required this.e1rmG,
    required this.e1rmFormatted,
  });

  factory E1rmPoint.fromJson(Map<String, dynamic> j) => E1rmPoint(
        date: (j['date'] ?? '').toString(),
        weightG: (j['weightG'] as num?)?.toInt() ?? 0,
        reps: (j['reps'] as num?)?.toInt() ?? 0,
        e1rmG: (j['e1rmG'] as num?)?.toInt() ?? 0,
        e1rmFormatted: (j['e1rmFormatted'] ?? '').toString(),
      );

  @override
  List<Object?> get props => [date, weightG, reps, e1rmG, e1rmFormatted];
}

/// GET /api/v1/training/progression/:exerciseId?range=
class Progression extends Equatable {
  final String metric;
  final List<E1rmPoint> points;
  final int currentE1rmG;
  final String currentE1rmFormatted;
  final int changeE1rmG;
  final String changeE1rmFormatted;

  const Progression({
    required this.metric,
    required this.points,
    required this.currentE1rmG,
    required this.currentE1rmFormatted,
    required this.changeE1rmG,
    required this.changeE1rmFormatted,
  });

  factory Progression.fromJson(Map<String, dynamic> j) => Progression(
        metric: (j['metric'] ?? 'weight').toString(),
        points: ((j['points'] as List?) ?? const [])
            .map((e) => E1rmPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        currentE1rmG: (j['currentE1rmG'] as num?)?.toInt() ?? 0,
        currentE1rmFormatted: (j['currentE1rmFormatted'] ?? '').toString(),
        changeE1rmG: (j['changeE1rmG'] as num?)?.toInt() ?? 0,
        changeE1rmFormatted: (j['changeE1rmFormatted'] ?? '').toString(),
      );

  bool get hasData => points.length >= 2;

  @override
  List<Object?> get props => [
        metric,
        points,
        currentE1rmG,
        currentE1rmFormatted,
        changeE1rmG,
        changeE1rmFormatted,
      ];
}

/// One muscle-group row in the volume card.
class VolumeGroup extends Equatable {
  final String muscleGroup; // English key: chest / back / quads …
  final int volumeG;
  final String volumeFormatted;
  final int sets;

  const VolumeGroup({
    required this.muscleGroup,
    required this.volumeG,
    required this.volumeFormatted,
    required this.sets,
  });

  factory VolumeGroup.fromJson(Map<String, dynamic> j) => VolumeGroup(
        muscleGroup: (j['muscleGroup'] ?? 'unknown').toString(),
        volumeG: (j['volumeG'] as num?)?.toInt() ?? 0,
        volumeFormatted: (j['volumeFormatted'] ?? '').toString(),
        sets: (j['sets'] as num?)?.toInt() ?? 0,
      );

  /// Russian label for the muscle-group key (design uses Ноги/Спина/…).
  String get labelRu => _muscleGroupRu[muscleGroup] ?? muscleGroup;

  @override
  List<Object?> get props => [muscleGroup, volumeG, volumeFormatted, sets];
}

const Map<String, String> _muscleGroupRu = {
  'chest': 'Грудь',
  'back': 'Спина',
  'quads': 'Ноги',
  'hamstrings': 'Задняя бедра',
  'glutes': 'Ягодицы',
  'shoulders': 'Плечи',
  'arms': 'Руки',
  'core': 'Кор',
  'legs': 'Ноги',
  'unknown': 'Прочее',
};

/// GET /api/v1/training/stats/volume?range=
class VolumeStats extends Equatable {
  final List<VolumeGroup> byGroup;
  final int totalVolumeG;
  final String totalVolumeFormatted;

  const VolumeStats({
    required this.byGroup,
    required this.totalVolumeG,
    required this.totalVolumeFormatted,
  });

  factory VolumeStats.fromJson(Map<String, dynamic> j) => VolumeStats(
        byGroup: ((j['byGroup'] as List?) ?? const [])
            .map((e) => VolumeGroup.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalVolumeG: (j['totalVolumeG'] as num?)?.toInt() ?? 0,
        totalVolumeFormatted: (j['totalVolumeFormatted'] ?? '').toString(),
      );

  bool get hasData => byGroup.isNotEmpty && totalVolumeG > 0;

  /// Largest group volume, for scaling the bars.
  int get maxVolumeG =>
      byGroup.isEmpty ? 0 : byGroup.map((g) => g.volumeG).reduce((a, b) => a > b ? a : b);

  @override
  List<Object?> get props => [byGroup, totalVolumeG, totalVolumeFormatted];
}

/// A selectable lift for the e1RM card.
class LiftOption {
  final String id;
  final String label;
  const LiftOption(this.id, this.label);
}

const List<LiftOption> kLiftOptions = [
  LiftOption('ex-bench_press', 'Жим лёжа'),
  LiftOption('ex-leg_press', 'Жим ногами'),
  LiftOption('ex-rdl_db', 'Румынская тяга'),
];

/// All progress data for the current range/lift selection.
class ProgressData extends Equatable {
  final WeightTrend weight;
  final Progression progression;
  final VolumeStats volume;

  const ProgressData({
    required this.weight,
    required this.progression,
    required this.volume,
  });

  @override
  List<Object?> get props => [weight, progression, volume];
}
