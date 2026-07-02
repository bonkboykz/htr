/// Models for the Insights (correlations) screen.
///
/// Backed by `GET /api/v1/correlations/insights`. Each insight is an
/// association the engine detected between a factor and a metric — the API
/// already builds a human, association-framed [summary] sentence which we
/// display verbatim (never phrased as causation).
library;

/// One detected association. `kind` is "correlation" (ρ / [coefficient]) or
/// "group" (high-vs-low day comparison, [deltaPct]).
class Insight {
  final String kind;
  final String factorSource;
  final String metricSource;
  final int lag;
  final double? coefficient; // present for kind == "correlation"
  final double? deltaPct; // present for kind == "group"
  final double pValue;
  final String significance; // high | medium | low | none
  final int dataPoints;
  final String summary;

  const Insight({
    required this.kind,
    required this.factorSource,
    required this.metricSource,
    required this.lag,
    required this.coefficient,
    required this.deltaPct,
    required this.pValue,
    required this.significance,
    required this.dataPoints,
    required this.summary,
  });

  /// True when the association points in the negative direction
  /// (metric lower / inverse relationship).
  bool get isNegative =>
      (deltaPct != null && deltaPct! < 0) ||
      (coefficient != null && coefficient! < 0);

  /// Strength magnitude in 0..1 for the strength bar.
  double get strength {
    if (coefficient != null) return coefficient!.abs().clamp(0.0, 1.0);
    if (deltaPct != null) return (deltaPct!.abs() / 100.0).clamp(0.0, 1.0);
    return 0.0;
  }

  /// Short signed label, e.g. "−18%" or "ρ = 0.72".
  String get strengthLabel {
    if (coefficient != null) return 'ρ = ${_num(coefficient!)}';
    if (deltaPct != null) {
      final sign = deltaPct! > 0 ? '+' : (deltaPct! < 0 ? '−' : '');
      return '$sign${_num(deltaPct!.abs())}%';
    }
    return '';
  }

  static String _num(double v) {
    final rounded = v.roundToDouble();
    return v == rounded ? rounded.toInt().toString() : v.toString();
  }

  static Insight fromJson(Map<String, dynamic> j) => Insight(
        kind: (j['kind'] ?? 'correlation').toString(),
        factorSource: (j['factorSource'] ?? '').toString(),
        metricSource: (j['metricSource'] ?? '').toString(),
        lag: (j['lag'] as num?)?.toInt() ?? 0,
        coefficient: (j['coefficient'] as num?)?.toDouble(),
        deltaPct: (j['deltaPct'] as num?)?.toDouble(),
        pValue: (j['pValue'] as num?)?.toDouble() ?? 1.0,
        significance: (j['significance'] ?? 'none').toString(),
        dataPoints: (j['dataPoints'] as num?)?.toInt() ?? 0,
        summary: (j['summary'] ?? '').toString(),
      );
}
