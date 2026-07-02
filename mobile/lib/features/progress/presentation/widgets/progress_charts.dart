import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../data/progress_models.dart';

const List<String> _ruMonths = [
  'янв', 'фев', 'мар', 'апр', 'май', 'июн',
  'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
];

/// "2026-07-02" → "2 июл". Returns '' on parse failure.
String _shortDate(String iso) {
  final parts = iso.split('-');
  if (parts.length != 3) return '';
  final month = int.tryParse(parts[1]) ?? 0;
  final day = int.tryParse(parts[2]) ?? 0;
  if (month < 1 || month > 12) return '';
  return '$day ${_ruMonths[month - 1]}';
}

TextStyle get _axisStyle =>
    const TextStyle(color: AppColors.textMuted, fontSize: 11);

/// EMA-style weight line chart (kg over time) with a soft filled area.
class WeightLineChart extends StatelessWidget {
  final List<WeightPoint> entries;
  const WeightLineChart({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[
      for (var i = 0; i < entries.length; i++)
        FlSpot(i.toDouble(), entries[i].weightGrams / 1000),
    ];
    final ys = spots.map((s) => s.y).toList();
    var minY = ys.reduce((a, b) => a < b ? a : b);
    var maxY = ys.reduce((a, b) => a > b ? a : b);
    final pad = ((maxY - minY) * 0.15).clamp(0.5, 5.0);
    minY -= pad;
    maxY += pad;

    final lastIdx = entries.length - 1;
    // Aim for ~4 date labels across the axis.
    final step = (entries.length / 4).ceil().clamp(1, entries.length);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: lastIdx.toDouble(),
        minY: minY,
        maxY: maxY,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.round();
                if (i < 0 || i >= entries.length) {
                  return const SizedBox.shrink();
                }
                final show = i == 0 || i == lastIdx || i % step == 0;
                if (!show) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_shortDate(entries[i].date), style: _axisStyle),
                );
              },
            ),
          ),
        ),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: AppColors.accent,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              checkToShowDot: (spot, _) => spot.x == lastIdx.toDouble(),
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 5,
                color: AppColors.accent,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.accent.withValues(alpha: 0.10),
            ),
          ),
        ],
      ),
    );
  }
}

/// e1RM column chart — the latest bar is highlighted (design: solid accent).
class E1rmBarChart extends StatelessWidget {
  final List<E1rmPoint> points;
  const E1rmBarChart({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    final maxKg = points
        .map((p) => p.e1rmG / 1000)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final lastIdx = points.length - 1;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceBetween,
        maxY: maxKg * 1.15,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        barTouchData: BarTouchData(enabled: false),
        barGroups: [
          for (var i = 0; i < points.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: points[i].e1rmG / 1000,
                  color: i == lastIdx ? AppColors.accent : AppColors.accentSoft,
                  width: 12,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
