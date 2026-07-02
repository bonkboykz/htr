import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/di/di.dart';
import '../../../core/network/api_client.dart';
import '../cubit/workout_cubit.dart';
import '../data/workout_models.dart';
import '../data/workout_repository.dart';
import 'widgets/set_stepper.dart';

String _formatKg(int grams) {
  final kg = grams / 1000;
  final s = kg.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

String _formatClock(int seconds) {
  final m = (seconds ~/ 60).toString().padLeft(2, '0');
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

class WorkoutPage extends StatelessWidget {
  const WorkoutPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) =>
            WorkoutCubit(WorkoutRepository(sl<ApiClient>()))..load(),
        child: const _WorkoutView(),
      );
}

class _WorkoutView extends StatelessWidget {
  const _WorkoutView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocConsumer<WorkoutCubit, WorkoutState>(
          listenWhen: (a, b) =>
              a.summaryDurationS != b.summaryDurationS ||
              (a.error != b.error && b.error != null),
          listener: (context, state) {
            if (state.summaryDurationS != null) {
              _showSummary(context, state.summaryDurationS!);
            } else if (state.error != null && !state.unauthorized) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(state.error!)));
            }
          },
          builder: (context, state) {
            switch (state.status) {
              case WorkoutStatus.initial:
              case WorkoutStatus.loading:
                return const Center(child: CircularProgressIndicator());
              case WorkoutStatus.error:
                return _ErrorView(state: state);
              case WorkoutStatus.ready:
                return _Content(state: state);
            }
          },
        ),
      ),
    );
  }

  void _showSummary(BuildContext context, int durationS) {
    final cubit = context.read<WorkoutCubit>();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        icon: const Icon(Icons.emoji_events_outlined,
            color: AppColors.accent, size: 40),
        title: const Text('Тренировка завершена'),
        content: Text(
          'Длительность: ${_formatClock(durationS)}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              cubit.dismissSummaryAndReload();
            },
            child: const Text('Готово'),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final WorkoutState state;
  const _ErrorView({required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<WorkoutCubit>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              state.unauthorized ? Icons.key_off_outlined : Icons.error_outline,
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

class _Content extends StatelessWidget {
  final WorkoutState state;
  const _Content({required this.state});

  @override
  Widget build(BuildContext context) {
    final plan = state.plan!;
    return Column(
      children: [
        _Header(state: state),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              const _ProgramCard(),
              const SizedBox(height: 20),
              if (plan.warmup.isNotEmpty) ...[
                _SectionHeader(
                  title: 'РАЗМИНКА',
                  color: AppColors.amber,
                  trailing: '${plan.warmup.length} упражнения',
                ),
                const SizedBox(height: 8),
                _SimpleList(items: plan.warmup, accent: AppColors.amber),
                const SizedBox(height: 20),
              ],
              if (plan.main.isNotEmpty) ...[
                _SectionHeader(
                  title: 'ОСНОВНАЯ',
                  color: AppColors.accent,
                  trailing: '${plan.main.length} упражнений',
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < plan.main.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _MainExercise(
                      item: plan.main[i],
                      number: i + 1,
                      state: state,
                    ),
                  ),
                const SizedBox(height: 12),
              ],
              if (plan.reab.isNotEmpty) ...[
                _SectionHeader(
                  title: 'РЕАБ-БЛОК',
                  color: AppColors.danger,
                  trailing: 'кор',
                ),
                const SizedBox(height: 8),
                _SimpleList(items: plan.reab, accent: AppColors.danger),
              ],
            ],
          ),
        ),
        _FinishBar(state: state),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final WorkoutState state;
  const _Header({required this.state});

  @override
  Widget build(BuildContext context) {
    final plan = state.plan!;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
      color: AppColors.bg,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: () => context.canPop() ? context.pop() : null,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.displayName.isEmpty ? 'Тренировка' : plan.displayName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Занятие ${plan.sessionIndex}/10'
                      '${plan.routineName.isNotEmpty ? ' · ${plan.routineName}' : ''}',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (plan.isRampup)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text('ramp-up',
                          style: TextStyle(
                              color: AppColors.green,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 24,
                  color: state.sessionActive
                      ? AppColors.accent
                      : AppColors.textMuted,
                ),
                const SizedBox(width: 10),
                Text(
                  _formatClock(state.elapsedSeconds),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const Spacer(),
                if (!state.sessionActive)
                  const Text(
                    'старт с 1-го подхода',
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  const _ProgramCard();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accentSoft,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.card),
        onTap: () => context.push('/workout/program'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.checklist_rtl,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Программа тренировок',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    SizedBox(height: 2),
                    Text('Все routine и планы',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  final String? trailing;
  const _SectionHeader({required this.title, required this.color, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: color,
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
        const Spacer(),
        if (trailing != null)
          Text(
            trailing!,
            style: TextStyle(
              fontSize: 13,
              color: color == AppColors.danger
                  ? AppColors.danger
                  : AppColors.textMuted,
            ),
          ),
      ],
    );
  }
}

/// Warmup / reab compact rows with a "log one set" play button.
class _SimpleList extends StatelessWidget {
  final List<PlanItem> items;
  final Color accent;
  const _SimpleList({required this.items, required this.accent});

  @override
  Widget build(BuildContext context) {
    final isReab = accent == AppColors.danger;
    return Container(
      decoration: BoxDecoration(
        color: isReab ? AppColors.dangerSoft : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(
            color: isReab ? AppColors.danger.withValues(alpha: 0.25) : AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                color: isReab
                    ? AppColors.danger.withValues(alpha: 0.15)
                    : AppColors.border,
              ),
            _SimpleRow(item: items[i], accent: accent),
          ],
        ],
      ),
    );
  }
}

class _SimpleRow extends StatelessWidget {
  final PlanItem item;
  final Color accent;
  const _SimpleRow({required this.item, required this.accent});

  @override
  Widget build(BuildContext context) {
    final re = item.routineExercise;
    final logged = context
            .select<WorkoutCubit, int>((c) => c.state.logged[re.id]?.length ?? 0);
    final done = logged >= re.targetSets && re.targetSets > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.exercise.displayName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: done ? AppColors.textMuted : AppColors.textPrimary,
                decoration: done ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          Text(
            re.setsRepsLabel,
            style: TextStyle(
              color: accent == AppColors.danger
                  ? AppColors.danger
                  : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          _RoundIconButton(
            icon: done ? Icons.check : Icons.play_arrow,
            color: accent,
            onTap: () => context.read<WorkoutCubit>().logSet(item),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _RoundIconButton(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: CircleBorder(side: BorderSide(color: color.withValues(alpha: 0.5))),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}

/// Main-section exercise: collapsed summary or expanded logging UI.
class _MainExercise extends StatelessWidget {
  final PlanItem item;
  final int number;
  final WorkoutState state;
  const _MainExercise(
      {required this.item, required this.number, required this.state});

  @override
  Widget build(BuildContext context) {
    final re = item.routineExercise;
    final expanded = state.expandedId == re.id;
    final cubit = context.read<WorkoutCubit>();
    final loggedSets = state.logged[re.id] ?? const <LoggedSet>[];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(
          color: expanded ? AppColors.accent : AppColors.border,
          width: expanded ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.card),
          onTap: () => cubit.toggleExpanded(re.id),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: expanded
                ? _ExpandedBody(
                    item: item,
                    number: number,
                    state: state,
                    loggedSets: loggedSets,
                  )
                : _CollapsedBody(
                    item: item, number: number, loggedCount: loggedSets.length),
          ),
        ),
      ),
    );
  }
}

class _NumberBadge extends StatelessWidget {
  final int number;
  final bool active;
  const _NumberBadge({required this.number, this.active = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? AppColors.accentSoft : AppColors.bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        number.toString().padLeft(2, '0'),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: active ? AppColors.accent : AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _CollapsedBody extends StatelessWidget {
  final PlanItem item;
  final int number;
  final int loggedCount;
  const _CollapsedBody(
      {required this.item, required this.number, required this.loggedCount});

  @override
  Widget build(BuildContext context) {
    final re = item.routineExercise;
    final last = item.last;
    final done = loggedCount >= re.targetSets && re.targetSets > 0;
    return Row(
      children: [
        _NumberBadge(number: number),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.exercise.displayName,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                'Цель ${re.setsRepsLabel}'
                '${last != null ? ' · прошлый раз ${last.weightFormatted}' : ''}',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
        if (done)
          const Icon(Icons.check_circle, color: AppColors.green, size: 22)
        else
          const Icon(Icons.chevron_right, color: AppColors.textMuted),
      ],
    );
  }
}

class _ExpandedBody extends StatelessWidget {
  final PlanItem item;
  final int number;
  final WorkoutState state;
  final List<LoggedSet> loggedSets;
  const _ExpandedBody({
    required this.item,
    required this.number,
    required this.state,
    required this.loggedSets,
  });

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<WorkoutCubit>();
    final re = item.routineExercise;
    final ex = item.exercise;
    final input = state.inputs[re.id] ??
        const SetInput(weightG: 0, reps: 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _NumberBadge(number: number, active: true),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                ex.displayName,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            if (item.suggestion != null && item.suggestion!.action.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  item.suggestion!.action,
                  style: const TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 12),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Chip(label: 'Цель ${re.setsRepsLabel}'),
            if (re.targetRir != null) _Chip(label: 'RIR ${re.targetRir}'),
          ],
        ),
        if (item.last != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.history,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Прошлый раз: ${_lastSummary(item)}',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
        if (item.suggestion != null &&
            item.suggestion!.rationale.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(AppRadii.inner),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline,
                    size: 18, color: AppColors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.suggestion!.rationale,
                    style: const TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w500,
                        fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (loggedSets.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Готово:',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final s in loggedSets)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_formatKg(s.weightG)} × ${s.reps}',
                          style: const TextStyle(
                              color: AppColors.green,
                              fontWeight: FontWeight.w600,
                              fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                'подход ${loggedSets.length}/${re.targetSets}',
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        // Weight on its own row (wider, primary control)…
        Row(
          children: [
            Expanded(
              child: SetStepper(
                label: 'Вес, кг',
                value: _formatKg(input.weightG),
                onMinus: () => cubit.stepWeight(re.id, -ex.minIncrementG),
                onPlus: () => cubit.stepWeight(re.id, ex.minIncrementG),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // …reps + RIR share the next row.
        Row(
          children: [
            Expanded(
              child: SetStepper(
                label: 'Повторы',
                value: '${input.reps}',
                onMinus: () => cubit.stepReps(re.id, -1),
                onPlus: () => cubit.stepReps(re.id, 1),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SetStepper(
                label: 'RIR',
                value: input.rir?.toString() ?? '—',
                onMinus: () => cubit.stepRir(re.id, -1),
                onPlus: () => cubit.stepRir(re.id, 1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: state.busy ? null : () => cubit.logSet(item),
                icon: const Icon(Icons.check, size: 20),
                label: const Text('Записать подход'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _lastSummary(PlanItem item) {
    return item.lastPerformance
        .map((p) => '${_formatKg(p.weightG)}×${p.reps}')
        .join(', ');
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary),
      ),
    );
  }
}

class _FinishBar extends StatelessWidget {
  final WorkoutState state;
  const _FinishBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<WorkoutCubit>();
    final enabled = state.sessionActive && !state.busy;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: FilledButton.icon(
        onPressed: enabled ? () => cubit.finish() : null,
        icon: state.busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.flag_outlined),
        label: const Text('Завершить тренировку'),
      ),
    );
  }
}
