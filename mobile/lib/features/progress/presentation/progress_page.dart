import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme.dart';
import '../../../core/di/di.dart';
import '../../../core/network/api_client.dart';
import '../cubit/progress_cubit.dart';
import '../data/progress_models.dart';
import '../data/progress_repository.dart';
import 'widgets/progress_charts.dart';

class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) =>
            ProgressCubit(ProgressRepository(sl<ApiClient>()))..load(),
        child: const _ProgressView(),
      );
}

class _ProgressView extends StatelessWidget {
  const _ProgressView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<ProgressCubit, ProgressState>(
          builder: (context, state) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Header(),
                _RangeControl(range: state.range),
                Expanded(child: _Body(state: state)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Text('Прогресс', style: Theme.of(context).textTheme.headlineLarge),
    );
  }
}

class _RangeControl extends StatelessWidget {
  final ProgressRange range;
  const _RangeControl({required this.range});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProgressCubit>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(AppRadii.inner),
        ),
        child: Row(
          children: [
            for (final r in ProgressRange.values)
              Expanded(
                child: GestureDetector(
                  onTap: () => cubit.selectRange(r),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: r == range ? AppColors.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadii.inner - 4),
                    ),
                    child: Text(
                      r.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: r == range
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final ProgressState state;
  const _Body({required this.state});

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case ProgressStatus.initial:
      case ProgressStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case ProgressStatus.error:
        return _ErrorView(state: state);
      case ProgressStatus.ready:
        final data = state.data!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _WeightCard(trend: data.weight, range: state.range),
            const SizedBox(height: 20),
            const _SectionHeader(title: 'СИЛА И ОБЪЁМ'),
            const SizedBox(height: 12),
            _E1rmCard(
              progression: data.progression,
              exerciseId: state.exerciseId,
              range: state.range,
            ),
            const SizedBox(height: 20),
            _VolumeCard(volume: data.volume, range: state.range),
          ],
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Weight trend card
// ---------------------------------------------------------------------------

class _WeightCard extends StatelessWidget {
  final WeightTrend trend;
  final ProgressRange range;
  const _WeightCard({required this.trend, required this.range});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Text(
                  'Вес · тренд (EMA)',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                ),
              ),
              if (trend.hasData) _WeightChangeBadge(trend: trend, range: range),
            ],
          ),
          const SizedBox(height: 6),
          if (trend.hasData)
            _BigValue(text: trend.currentFormatted)
          else
            const SizedBox.shrink(),
          const SizedBox(height: 16),
          if (trend.hasData)
            SizedBox(height: 170, child: WeightLineChart(entries: trend.entries))
          else
            const _EmptyChart(height: 170),
        ],
      ),
    );
  }
}

class _WeightChangeBadge extends StatelessWidget {
  final WeightTrend trend;
  final ProgressRange range;
  const _WeightChangeBadge({required this.trend, required this.range});

  @override
  Widget build(BuildContext context) {
    // Loss (change <= 0) reads as progress → green; gain → amber.
    final isLoss = trend.changeGrams <= 0;
    final color = isLoss ? AppColors.green : AppColors.amber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isLoss ? LucideIcons.trendingDown : LucideIcons.trendingUp,
              size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '${trend.changeFormatted} / ${range.periodLabel}',
            style: TextStyle(
                color: color, fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// e1RM card
// ---------------------------------------------------------------------------

class _E1rmCard extends StatelessWidget {
  final Progression progression;
  final String exerciseId;
  final ProgressRange range;
  const _E1rmCard({
    required this.progression,
    required this.exerciseId,
    required this.range,
  });

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProgressCubit>();
    final label = kLiftOptions
        .firstWhere((l) => l.id == exerciseId,
            orElse: () => LiftOption(exerciseId, exerciseId))
        .label;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _LiftDropdown(exerciseId: exerciseId, cubit: cubit)),
              const SizedBox(width: 8),
              if (progression.points.isNotEmpty)
                _E1rmChangeBadge(progression: progression, range: range),
            ],
          ),
          const SizedBox(height: 8),
          if (progression.points.isNotEmpty)
            _BigValue(text: progression.currentE1rmFormatted)
          else
            const SizedBox.shrink(),
          const SizedBox(height: 4),
          Text(
            '$label · e1RM (Epley)',
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          if (progression.hasData)
            SizedBox(height: 150, child: E1rmBarChart(points: progression.points))
          else
            const _EmptyChart(height: 150),
        ],
      ),
    );
  }
}

class _LiftDropdown extends StatelessWidget {
  final String exerciseId;
  final ProgressCubit cubit;
  const _LiftDropdown({required this.exerciseId, required this.cubit});

  @override
  Widget build(BuildContext context) {
    final ids = kLiftOptions.map((l) => l.id).toList();
    final value = ids.contains(exerciseId) ? exerciseId : ids.first;
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        isDense: true,
        icon: const Icon(LucideIcons.chevronDown,
            size: 18, color: AppColors.textSecondary),
        style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600),
        borderRadius: BorderRadius.circular(AppRadii.inner),
        onChanged: (v) {
          if (v != null) cubit.selectLift(v);
        },
        items: [
          for (final lift in kLiftOptions)
            DropdownMenuItem(value: lift.id, child: Text(lift.label)),
        ],
      ),
    );
  }
}

class _E1rmChangeBadge extends StatelessWidget {
  final Progression progression;
  final ProgressRange range;
  const _E1rmChangeBadge({required this.progression, required this.range});

  @override
  Widget build(BuildContext context) {
    final up = progression.changeE1rmG >= 0;
    final sign = up ? '+' : '−';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(up ? LucideIcons.trendingUp : LucideIcons.trendingDown,
              size: 16, color: AppColors.accent),
          const SizedBox(width: 6),
          Text(
            '$sign${progression.changeE1rmFormatted} / ${range.periodLabel}',
            style: const TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
                fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Volume-by-group card
// ---------------------------------------------------------------------------

class _VolumeCard extends StatelessWidget {
  final VolumeStats volume;
  final ProgressRange range;
  const _VolumeCard({required this.volume, required this.range});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Объём по группам · ${range.sectionLabel}',
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                ),
              ),
              if (volume.hasData)
                Text(
                  volume.totalVolumeFormatted,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (volume.hasData)
            for (final g in volume.byGroup)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _VolumeRow(group: g, maxVolumeG: volume.maxVolumeG),
              )
          else
            const _EmptyHint(),
        ],
      ),
    );
  }
}

class _VolumeRow extends StatelessWidget {
  final VolumeGroup group;
  final int maxVolumeG;
  const _VolumeRow({required this.group, required this.maxVolumeG});

  @override
  Widget build(BuildContext context) {
    final fraction = maxVolumeG <= 0 ? 0.0 : group.volumeG / maxVolumeG;
    return Row(
      children: [
        SizedBox(
          width: 74,
          child: Text(
            group.labelRu,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: Container(
              height: 20,
              color: AppColors.border,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: fraction.clamp(0.02, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 56,
          child: Text(
            group.volumeFormatted,
            textAlign: TextAlign.right,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared bits
// ---------------------------------------------------------------------------

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _BigValue extends StatelessWidget {
  final String text;
  const _BigValue({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        height: 1.0,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 0.5,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _EmptyChart extends StatelessWidget {
  final double height;
  const _EmptyChart({required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: const _EmptyHint(),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.barChart3, size: 28, color: AppColors.textMuted),
          SizedBox(height: 8),
          Text(
            'Недостаточно данных',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final ProgressState state;
  const _ErrorView({required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProgressCubit>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              state.unauthorized ? LucideIcons.keyRound : LucideIcons.cloudOff,
              size: 40,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              state.unauthorized ? 'Нужен API-ключ' : 'Не удалось загрузить',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              state.error ?? 'Проверьте соединение и попробуйте снова.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            if (state.unauthorized)
              FilledButton(
                onPressed: () => context.push('/settings'),
                child: const Text('Открыть настройки'),
              )
            else
              FilledButton(
                onPressed: () => cubit.load(),
                child: const Text('Повторить'),
              ),
          ],
        ),
      ),
    );
  }
}
