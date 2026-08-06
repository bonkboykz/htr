import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme.dart';
import '../../../core/di/di.dart';
import '../../../core/network/api_client.dart';
import '../cubit/insights_cubit.dart';
import '../data/insights_models.dart';
import '../data/insights_repository.dart';

class InsightsPage extends StatelessWidget {
  const InsightsPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => InsightsCubit(InsightsRepository(sl<ApiClient>()))..load(),
        child: const _InsightsView(),
      );
}

class _InsightsView extends StatelessWidget {
  const _InsightsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<InsightsCubit, InsightsState>(
          builder: (context, state) {
            return RefreshIndicator(
              onRefresh: () => context.read<InsightsCubit>().load(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  const _Header(),
                  const SizedBox(height: 16),
                  _RangeControl(
                    range: state.range,
                    onChanged: (r) => context.read<InsightsCubit>().setRange(r),
                  ),
                  const SizedBox(height: 16),
                  const _DisclaimerBanner(),
                  const SizedBox(height: 16),
                  ..._body(context, state),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context, InsightsState state) {
    switch (state.status) {
      case InsightsStatus.initial:
      case InsightsStatus.loading:
        return const [
          Padding(
            padding: EdgeInsets.only(top: 48),
            child: Center(child: CircularProgressIndicator()),
          ),
        ];
      case InsightsStatus.error:
        return [
          _ErrorView(
            state: state,
            onRetry: () => context.read<InsightsCubit>().load(),
          ),
        ];
      case InsightsStatus.ready:
        if (state.insights.isEmpty) return const [_EmptyState()];
        return [
          for (final i in state.insights) ...[
            _InsightCard(insight: i),
            const SizedBox(height: 12),
          ],
        ];
    }
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Insights',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('вероятные связи в твоих данных',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.accentSoft,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: const Icon(LucideIcons.sparkles, color: AppColors.accent, size: 20),
        ),
      ],
    );
  }
}

// ── Range segmented control ───────────────────────────────────────────────────

class _RangeControl extends StatelessWidget {
  final InsightsRange range;
  final ValueChanged<InsightsRange> onChanged;
  const _RangeControl({required this.range, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(AppRadii.inner),
      ),
      child: Row(
        children: [
          for (final r in InsightsRange.values)
            Expanded(child: _segment(context, r)),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, InsightsRange r) {
    final selected = r == range;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.inner - 4),
        ),
        alignment: Alignment.center,
        child: Text(
          r.label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.textPrimary : AppColors.textSecondary,
              ),
        ),
      ),
    );
  }
}

// ── Disclaimer banner ─────────────────────────────────────────────────────────

class _DisclaimerBanner extends StatelessWidget {
  const _DisclaimerBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(AppRadii.inner),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.alertTriangle, size: 18, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Это вероятные связи, а не причинность. Нужно ≥7 дней данных.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Insight card ──────────────────────────────────────────────────────────────

class _InsightCard extends StatelessWidget {
  final Insight insight;
  const _InsightCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    final negative = insight.isNegative;
    final strengthColor = negative ? AppColors.danger : AppColors.accent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _StrengthTag(
                  color: strengthColor,
                  negative: negative,
                  label: insight.strengthLabel,
                ),
              ),
              const SizedBox(width: 8),
              _SignificanceChip(significance: insight.significance),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            insight.summary,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 14),
          _StrengthBar(value: insight.strength, color: strengthColor),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(LucideIcons.hash, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                'n = ${insight.dataPoints}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const Spacer(),
              if (insight.lag > 0) _LagBadge(lag: insight.lag),
            ],
          ),
        ],
      ),
    );
  }
}

/// Signed strength indicator: trending icon + value, colored by direction.
class _StrengthTag extends StatelessWidget {
  final Color color;
  final bool negative;
  final String label;
  const _StrengthTag({
    required this.color,
    required this.negative,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          negative ? LucideIcons.trendingDown : LucideIcons.trendingUp,
          size: 20,
          color: color,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}

class _StrengthBar extends StatelessWidget {
  final double value;
  final Color color;
  const _StrengthBar({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: 8,
        backgroundColor: AppColors.border,
        valueColor: AlwaysStoppedAnimation(color),
      ),
    );
  }
}

class _SignificanceChip extends StatelessWidget {
  final String significance;
  const _SignificanceChip({required this.significance});

  @override
  Widget build(BuildContext context) {
    late final Color color;
    late final String label;
    switch (significance) {
      case 'high':
        color = AppColors.green;
        label = 'высокая';
        break;
      case 'medium':
        color = AppColors.amber;
        label = 'средняя';
        break;
      case 'low':
        color = AppColors.textSecondary;
        label = 'низкая';
        break;
      default:
        color = AppColors.textMuted;
        label = 'нет';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            'значимость $label',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _LagBadge extends StatelessWidget {
  final int lag;
  const _LagBadge({required this.lag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        'лаг +$lag ${lag == 1 ? 'день' : 'дн'}',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(AppRadii.card),
              ),
              child: const Icon(LucideIcons.sparkles,
                  color: AppColors.accent, size: 28),
            ),
            const SizedBox(height: 16),
            Text('Пока недостаточно данных',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Логируй факторы и метрики хотя бы неделю — и здесь появятся вероятные связи.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final InsightsState state;
  final VoidCallback onRetry;
  const _ErrorView({required this.state, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final unauthorized = state.unauthorized;
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              unauthorized ? LucideIcons.keyRound : LucideIcons.cloudOff,
              size: 40,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              unauthorized ? 'Нужен API-ключ' : 'Не удалось загрузить',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                unauthorized
                    ? 'Укажите ключ в настройках, чтобы продолжить.'
                    : (state.error ?? 'Проверьте соединение и попробуйте снова.'),
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 20),
            unauthorized
                ? FilledButton(
                    onPressed: () => context.push('/settings'),
                    child: const Text('Открыть настройки'),
                  )
                : FilledButton(
                    onPressed: onRetry,
                    child: const Text('Повторить'),
                  ),
          ],
        ),
      ),
    );
  }
}
