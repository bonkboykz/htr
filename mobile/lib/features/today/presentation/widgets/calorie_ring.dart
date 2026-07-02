import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

/// Circular calories progress ring: big consumed number over "из {target}".
class CalorieRing extends StatelessWidget {
  final int consumed;
  final int target;
  final int progress; // 0-100

  const CalorieRing({
    super.key,
    required this.consumed,
    required this.target,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (progress.clamp(0, 100)) / 100.0;
    return SizedBox(
      width: 140,
      height: 140,
      child: CustomPaint(
        painter: _RingPainter(pct),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$consumed',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 34,
                    ),
              ),
              Text(
                'из $target',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double pct;
  _RingPainter(this.pct);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = AppColors.border;
    canvas.drawArc(rect, 0, 2 * math.pi, false, track);

    if (pct > 0) {
      final arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = AppColors.accent;
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * pct, false, arc);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.pct != pct;
}
