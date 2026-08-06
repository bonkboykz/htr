import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/di/di.dart';
import '../../../core/network/api_client.dart';
import '../cubit/today_cubit.dart';
import '../data/today_models.dart';
import '../data/today_repository.dart';
import 'widgets/calorie_ring.dart';

class TodayPage extends StatelessWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => TodayCubit(TodayRepository(sl<ApiClient>()))..load(),
        child: const _TodayView(),
      );
}

class _TodayView extends StatelessWidget {
  const _TodayView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<TodayCubit, TodayState>(
          builder: (context, state) {
            switch (state.status) {
              case TodayStatus.initial:
              case TodayStatus.loading:
                return const Center(child: CircularProgressIndicator());
              case TodayStatus.error:
                return _ErrorView(
                  state: state,
                  onRetry: () => context.read<TodayCubit>().load(),
                );
              case TodayStatus.ready:
                return _Content(data: state.data!);
            }
          },
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  final TodayData data;
  const _Content({required this.data});

  @override
  Widget build(BuildContext context) {
    final s = data.summary;
    return RefreshIndicator(
      onRefresh: () => context.read<TodayCubit>().load(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const _Header(),
          const SizedBox(height: 16),
          _CaloriesCard(budget: s.caloriesBudget, totals: s.nutrition),
          const SizedBox(height: 12),
          _MacrosCard(
            totals: s.nutrition,
            targetCalories: s.caloriesBudget?.targetCalories ?? 0,
          ),
          const SizedBox(height: 12),
          _MiniRow(water: s.water, sleep: s.sleep, weight: s.weight),
          const SizedBox(height: 12),
          _WorkoutCard(training: data.training),
          const SizedBox(height: 12),
          const _FactorsRow(),
        ],
      ),
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header();

  static const _weekdays = [
    'понедельник', 'вторник', 'среда', 'четверг', 'пятница', 'суббота', 'воскресенье',
  ];
  static const _months = [
    'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
    'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr =
        '${_weekdays[now.weekday - 1]}, ${now.day} ${_months[now.month - 1]}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Сегодня',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(dateStr,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(LucideIcons.settings),
          color: AppColors.textSecondary,
          onPressed: () => context.push('/settings'),
        ),
      ],
    );
  }
}

// ── Calories card ─────────────────────────────────────────────────────────────

class _CaloriesCard extends StatelessWidget {
  final CaloriesBudget? budget;
  final NutritionTotals totals;
  const _CaloriesCard({required this.budget, required this.totals});

  @override
  Widget build(BuildContext context) {
    final consumed = budget?.consumedCalories ?? totals.calories;
    final target = budget?.targetCalories ?? 0;
    final progress = budget?.progress ?? 0;

    return _Panel(
      child: Row(
        children: [
          CalorieRing(consumed: consumed, target: target, progress: progress),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Осталось',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(
                  budget?.remainingCaloriesFormatted ?? '${target - consumed}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                _LegendRow(
                  color: AppColors.textMuted,
                  label: 'Цель',
                  value: '$target ккал',
                ),
                const SizedBox(height: 8),
                _LegendRow(
                  color: AppColors.accent,
                  label: 'Съедено',
                  value: '$consumed ккал',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary)),
        const Spacer(),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// ── Macros card ───────────────────────────────────────────────────────────────

class _MacrosCard extends StatelessWidget {
  final NutritionTotals totals;

  /// TDEE calorie target; macro targets derive from it (30/25/45 split).
  final int targetCalories;
  const _MacrosCard({required this.totals, required this.targetCalories});

  @override
  Widget build(BuildContext context) {
    // Macro targets (tenths of grams) from the calorie target when available.
    final c = targetCalories;
    final proteinTgt = c > 0 ? (c * 0.30 / 4).round() * 10 : 0;
    final fatTgt = c > 0 ? (c * 0.25 / 9).round() * 10 : 0;
    final carbsTgt = c > 0 ? (c * 0.45 / 4).round() * 10 : 0;
    return _Panel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _MacroBar(
              label: 'Белки',
              value: totals.proteinFormatted,
              tenths: totals.protein,
              targetTenths: proteinTgt,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _MacroBar(
              label: 'Жиры',
              value: totals.fatFormatted,
              tenths: totals.fat,
              targetTenths: fatTgt,
              color: AppColors.amber,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _MacroBar(
              label: 'Углеводы',
              value: totals.carbsFormatted,
              tenths: totals.carbs,
              targetTenths: carbsTgt,
              color: AppColors.green,
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroBar extends StatelessWidget {
  final String label;
  final String value;
  final int tenths;
  final int targetTenths;
  final Color color;
  const _MacroBar({
    required this.label,
    required this.value,
    required this.tenths,
    required this.targetTenths,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Real fill against the (derived) target; 0 if there's no target at all.
    final fill =
        targetTenths > 0 ? (tenths / targetTenths).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(value.isEmpty ? '—' : value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: LinearProgressIndicator(
            value: fill,
            minHeight: 6,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        if (targetTenths > 0) ...[
          const SizedBox(height: 6),
          Text('из ${(targetTenths / 10).round()} г',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textMuted)),
        ],
      ],
    );
  }
}

// ── Mini cards row ────────────────────────────────────────────────────────────

class _MiniRow extends StatelessWidget {
  final WaterSummary water;
  final SleepSummary sleep;
  final WeightSummary? weight;
  const _MiniRow({required this.water, required this.sleep, required this.weight});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _MiniCard(
            icon: LucideIcons.droplet,
            iconColor: AppColors.water,
            iconBg: AppColors.water.withValues(alpha: 0.12),
            value: water.totalFormatted.isEmpty
                ? '${water.totalMl} ml'
                : water.totalFormatted,
            sub:
                'из ${water.targetFormatted.isEmpty ? '${water.targetMl} ml' : water.targetFormatted}',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MiniCard(
            icon: LucideIcons.moon,
            iconColor: AppColors.sleep,
            iconBg: AppColors.sleep.withValues(alpha: 0.12),
            value: sleep.totalFormatted.isEmpty ? '—' : sleep.totalFormatted,
            sub: 'цель ${(sleep.targetMinutes / 60).round()}ч',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MiniCard(
            icon: LucideIcons.scale,
            iconColor: AppColors.textSecondary,
            iconBg: AppColors.border,
            value: weight?.weightFormatted.replaceAll(' kg', '') ?? '—',
            sub: weight == null ? 'нет данных' : 'кг',
          ),
        ),
      ],
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String value;
  final String sub;
  const _MiniCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.value,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(AppRadii.inner),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(height: 14),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

// ── Workout card ──────────────────────────────────────────────────────────────

class _WorkoutCard extends StatelessWidget {
  final TrainingToday? training;
  const _WorkoutCard({required this.training});

  @override
  Widget build(BuildContext context) {
    final t = training;
    final title = t == null || t.routineLabel.isEmpty
        ? 'Тренировка'
        : 'Тренировка ${t.routineLabel}';
    final session = t?.sessionIndex;

    return Material(
      color: AppColors.accent,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.card),
        onTap: () => context.go('/workout'),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'СЛЕДУЮЩАЯ ТРЕНИРОВКА',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                    ),
                  ),
                  if (t?.isRampup == true)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('ramp-up',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  )),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      )),
              const SizedBox(height: 4),
              Text(
                session == null ? 'Занятие' : 'Занятие $session/10',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.accent,
                    minimumSize: const Size(140, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.inner),
                    ),
                  ),
                  onPressed: () => context.go('/workout'),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Начать'),
                      SizedBox(width: 8),
                      Icon(LucideIcons.arrowRight, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Factors row ───────────────────────────────────────────────────────────────

class _FactorsRow extends StatelessWidget {
  const _FactorsRow();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        onTap: () => context.push('/today/factors'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.accentSoft,
            borderRadius: BorderRadius.circular(AppRadii.inner),
          ),
          child: const Icon(LucideIcons.clipboardList, color: AppColors.accent),
        ),
        title: Text('Факторы дня',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        subtitle: Text('Настроение, сон, привычки',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary)),
        trailing: const Icon(LucideIcons.chevronRight, color: AppColors.textMuted),
      ),
    );
  }
}

// ── Shared bits ───────────────────────────────────────────────────────────────

class _Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _Panel({required this.child, this.padding = const EdgeInsets.all(20)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _ErrorView extends StatelessWidget {
  final TodayState state;
  final VoidCallback onRetry;
  const _ErrorView({required this.state, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final unauthorized = state.unauthorized;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
            Text(
              unauthorized
                  ? 'Укажите ключ в настройках, чтобы продолжить.'
                  : (state.error ?? 'Проверьте соединение и попробуйте снова.'),
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
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
