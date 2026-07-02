// Plain Dart models for the Факторы (factor logging) screen.
//
// Mirrors `GET /api/v1/factor-logs?date=` which returns a list of category
// groups, each with its factors + the current day's log (or null).

class FactorCategory {
  final String id;
  final String name;
  final String? emoji;

  const FactorCategory({required this.id, required this.name, this.emoji});

  factory FactorCategory.fromJson(Map<String, dynamic> json) => FactorCategory(
        id: json['id'] as String,
        name: json['name'] as String,
        emoji: json['emoji'] as String?,
      );
}

class Factor {
  final String id;
  final String name;

  /// "rating" → bounded scale of chips; "count" → unbounded numeric stepper.
  final String kind;
  final int scaleMin;
  final int scaleMax;
  final String? unit;

  /// Optional hints keyed by scale value, e.g. {"1": "Ужасно", "5": "Отлично"}.
  final Map<String, String>? labels;

  const Factor({
    required this.id,
    required this.name,
    required this.kind,
    required this.scaleMin,
    required this.scaleMax,
    this.unit,
    this.labels,
  });

  bool get isCount => kind == 'count';

  factory Factor.fromJson(Map<String, dynamic> json) {
    final rawLabels = json['labels'];
    return Factor(
      id: json['id'] as String,
      name: json['name'] as String,
      kind: (json['kind'] as String?) ?? 'rating',
      scaleMin: (json['scaleMin'] as num?)?.toInt() ?? 0,
      scaleMax: (json['scaleMax'] as num?)?.toInt() ?? 5,
      unit: json['unit'] as String?,
      labels: rawLabels is Map
          ? rawLabels.map((k, v) => MapEntry(k.toString(), v.toString()))
          : null,
    );
  }
}

/// One factor together with its (optional) logged value for the day.
class FactorWithLog {
  final Factor factor;
  final int? value;

  const FactorWithLog({required this.factor, this.value});

  factory FactorWithLog.fromJson(Map<String, dynamic> json) {
    final log = json['log'];
    return FactorWithLog(
      factor: Factor.fromJson(json['factor'] as Map<String, dynamic>),
      value: log is Map ? (log['value'] as num?)?.toInt() : null,
    );
  }
}

/// A category card with its factors.
class FactorGroup {
  final FactorCategory category;
  final List<FactorWithLog> factors;

  const FactorGroup({required this.category, required this.factors});

  factory FactorGroup.fromJson(Map<String, dynamic> json) => FactorGroup(
        category:
            FactorCategory.fromJson(json['category'] as Map<String, dynamic>),
        factors: (json['factors'] as List<dynamic>)
            .map((e) => FactorWithLog.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
