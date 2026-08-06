import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme.dart';
import '../../../core/di/di.dart';
import '../../../core/network/api_client.dart';
import '../../../core/rest_timer/rest_alarm.dart';
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

const _months = [
  'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
  'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
];

String _formatDate(String iso) {
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return iso;
  return '${d.day} ${_months[d.month - 1]}';
}

/// "1ч 05м" / "42м" from a seconds count.
String _formatDurationShort(int? seconds) {
  if (seconds == null) return '—';
  final total = seconds ~/ 60;
  final h = total ~/ 60;
  final m = total % 60;
  if (h > 0) return '$hч ${m.toString().padLeft(2, '0')}м';
  return '$mм';
}

class WorkoutPage extends StatelessWidget {
  const WorkoutPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => WorkoutCubit(
          WorkoutRepository(sl<ApiClient>()),
          restAlarm: sl<RestAlarm>(),
        )..load(),
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
    if (!state.live) return _IdleView(state: state);
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
        if (state.restRemaining > 0) _RestBar(state: state),
        _FinishBar(state: state),
      ],
    );
  }
}

/// Rest countdown between sets. Buzzes when it hits 0 (see cubit) and can be
/// extended (+30 s) or skipped. Lives just above the finish bar. [#5]
class _RestBar extends StatelessWidget {
  final WorkoutState state;
  const _RestBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<WorkoutCubit>();
    final total = state.restTotal > 0 ? state.restTotal : 1;
    final progress = (state.restRemaining / total).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: AppColors.accentSoft,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.timerReset, color: AppColors.accent, size: 20),
          const SizedBox(width: 10),
          const Text('Отдых',
              style: TextStyle(
                  color: AppColors.accent, fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.accent),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _formatClock(state.restRemaining),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: AppColors.accent,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 6),
          TextButton(
            onPressed: () => cubit.addRest(30),
            style: TextButton.styleFrom(
                minimumSize: const Size(40, 36),
                padding: const EdgeInsets.symmetric(horizontal: 8)),
            child: const Text('+30'),
          ),
          TextButton(
            onPressed: cubit.skipRest,
            style: TextButton.styleFrom(
                minimumSize: const Size(40, 36),
                padding: const EdgeInsets.symmetric(horizontal: 8)),
            child: const Text('Пропустить'),
          ),
        ],
      ),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: AppColors.bg,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
    final inProgress = logged > 0 && !done;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          // Name + "how-to" affordance — tap opens the technique sheet.
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _openExerciseInfo(context, item.exercise),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.exercise.displayName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color:
                              done ? AppColors.textMuted : AppColors.textPrimary,
                          decoration: done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    if (re.isOptional) ...[
                      const SizedBox(width: 8),
                      const _OptionalBadge(),
                    ],
                    const SizedBox(width: 6),
                    Icon(LucideIcons.playCircle,
                        size: 15, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
          ),
          Text(
            inProgress ? '$logged/${re.targetSets}' : re.setsRepsLabel,
            style: TextStyle(
              color: accent == AppColors.danger
                  ? AppColors.danger
                  : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          _DoneButton(
            done: done,
            accent: accent,
            onTap: () => context.read<WorkoutCubit>().logSet(item),
          ),
        ],
      ),
    );
  }
}

/// Warmup/reab "mark a set done" control: a tickable check (not a play icon).
/// Bordered check when pending → filled green check when the target is met.
class _DoneButton extends StatelessWidget {
  final bool done;
  final Color accent;
  final VoidCallback onTap;
  const _DoneButton(
      {required this.done, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: done ? AppColors.green : Colors.transparent,
      shape: done
          ? const CircleBorder()
          : CircleBorder(side: BorderSide(color: accent.withValues(alpha: 0.5))),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.check,
              size: 20, color: done ? Colors.white : accent),
        ),
      ),
    );
  }
}

/// Bottom sheet with an exercise's muscles, equipment, coaching cues and a
/// "Смотреть технику" link — reachable from warmup/reab rows (which have no
/// expanded card). [technique-for-all]
void _openExerciseInfo(BuildContext context, Exercise ex) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ExerciseInfoSheet(exercise: ex),
  );
}

class _ExerciseInfoSheet extends StatelessWidget {
  final Exercise exercise;
  const _ExerciseInfoSheet({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    final muscle = exercise.muscleLabel;
    if (muscle != null) {
      chips.add(_MetaChip(icon: LucideIcons.target, text: muscle));
    }
    for (final e in exercise.equipmentLabels) {
      chips.add(_MetaChip(icon: LucideIcons.dumbbell, text: e));
    }
    final cues = exercise.cuesRu?.trim() ?? '';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    exercise.displayName,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: AppColors.textMuted),
                ),
              ],
            ),
            if (chips.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(spacing: 12, runSpacing: 6, children: chips),
            ],
            if (cues.isNotEmpty) ...[
              const SizedBox(height: 14),
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
                      child: Text(cues,
                          style: const TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w500,
                              fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _openVideo(context, exercise);
                },
                icon: const Icon(LucideIcons.playCircle, size: 20),
                label: const Text('Смотреть технику'),
              ),
            ),
          ],
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
              Row(
                children: [
                  Flexible(
                    child: Text(
                      item.exercise.displayName,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (re.isOptional) ...[
                    const SizedBox(width: 8),
                    const _OptionalBadge(),
                  ],
                ],
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
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      ex.displayName,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (re.isOptional) ...[
                    const SizedBox(width: 8),
                    const _OptionalBadge(),
                  ],
                ],
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
        const SizedBox(height: 10),
        _MuscleVideoRow(exercise: ex),
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
                    for (var i = 0; i < loggedSets.length; i++)
                      _LoggedPill(
                        set: loggedSets[i],
                        onTap: () => _editLoggedSet(
                            context, cubit, ex, re.id, i, loggedSets[i]),
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
                label: ex.isDumbbell ? 'Вес, кг (одна гантель)' : 'Вес, кг',
                value: _formatKg(input.weightG),
                onMinus: () => cubit.stepWeight(re.id, -ex.minIncrementG),
                onPlus: () => cubit.stepWeight(re.id, ex.minIncrementG),
                onTapValue: () async {
                  final kg = await _promptNumber(
                    context,
                    title: 'Вес, кг',
                    initial: input.weightG / 1000,
                    allowDecimal: true,
                  );
                  if (kg != null) cubit.setWeightG(re.id, (kg * 1000).round());
                },
              ),
            ),
          ],
        ),
        if (ex.isDumbbell) ...[
          const SizedBox(height: 6),
          Row(
            children: const [
              Icon(Icons.info_outline, size: 14, color: AppColors.textMuted),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Записывайте вес одной гантели, не сумму двух.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
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
                onTapValue: () async {
                  final n = await _promptNumber(
                    context,
                    title: 'Повторы',
                    initial: input.reps.toDouble(),
                    allowDecimal: false,
                  );
                  if (n != null) cubit.setReps(re.id, n.round());
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SetStepper(
                label: 'RIR',
                value: input.rir?.toString() ?? '—',
                onMinus: () => cubit.stepRir(re.id, -1),
                onPlus: () => cubit.stepRir(re.id, 1),
                onTapValue: () async {
                  final n = await _promptNumber(
                    context,
                    title: 'RIR (запас повторов)',
                    initial: (input.rir ?? 2).toDouble(),
                    allowDecimal: false,
                  );
                  if (n != null) cubit.setRir(re.id, n.round());
                },
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
            : const Icon(LucideIcons.flag),
        label: const Text('Завершить тренировку'),
      ),
    );
  }
}

/// Shown when there is no active session: a "Начать тренировку" card + История.
class _IdleView extends StatelessWidget {
  final WorkoutState state;
  const _IdleView({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          color: AppColors.bg,
          child: Text(
            'Тренировка',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _StartCard(state: state),
              const SizedBox(height: 12),
              const _ProgramCard(),
              const SizedBox(height: 24),
              if (state.history.isNotEmpty) ...[
                _SectionHeader(
                  title: 'ИСТОРИЯ',
                  color: AppColors.accent,
                  trailing: '${state.history.length}',
                ),
                const SizedBox(height: 8),
                for (final s in state.history)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _HistoryRow(session: s),
                  ),
              ] else
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Пока нет завершённых тренировок.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StartCard extends StatelessWidget {
  final WorkoutState state;
  const _StartCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final plan = state.plan;
    final name = (plan != null && plan.displayName.isNotEmpty)
        ? plan.displayName
        : 'Тренировка';
    final sessionIndex = plan?.sessionIndex ?? state.today?.sessionIndex ?? 0;
    final isRampup = plan?.isRampup ?? state.today?.isRampup ?? false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      'Занятие $sessionIndex/10',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
              ),
              if (isRampup)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: const Text('ramp-up',
                      style: TextStyle(
                          color: AppColors.green,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: state.busy
                  ? null
                  : () => context.read<WorkoutCubit>().startWorkout(),
              icon: state.busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(LucideIcons.play, size: 20),
              label: const Text('Начать'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final SessionSummary session;
  const _HistoryRow({required this.session});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<WorkoutCubit>();
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.card),
        // Reload on return so a deleted/edited session is reflected here. [#delete-refresh]
        onTap: () async {
          await context.push('/workout/session/${session.id}');
          cubit.load();
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _formatDate(session.startedAt),
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Занятие ${session.sessionIndex}',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      session.routineName.isEmpty
                          ? 'Тренировка'
                          : session.routineName,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        _MetaChip(
                          icon: LucideIcons.timer,
                          text: _formatDurationShort(session.durationS),
                        ),
                        _MetaChip(
                          icon: LucideIcons.dumbbell,
                          text: session.volumeFormatted,
                        ),
                        _MetaChip(
                          icon: LucideIcons.listChecks,
                          text: '${session.totalSets} подх.',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(LucideIcons.chevronRight,
                  color: AppColors.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

/// "необяз." pill for accessory exercises the user may skip. [#8/#10]
class _OptionalBadge extends StatelessWidget {
  const _OptionalBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: const Text(
        'необяз.',
        style: TextStyle(
            color: AppColors.amber, fontWeight: FontWeight.w600, fontSize: 11),
      ),
    );
  }
}

/// Target muscles + equipment + a link to a technique video. [#1, #3, #7]
class _MuscleVideoRow extends StatelessWidget {
  final Exercise exercise;
  const _MuscleVideoRow({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    final muscle = exercise.muscleLabel;
    if (muscle != null) {
      chips.add(_MetaChip(icon: LucideIcons.target, text: muscle));
    }
    for (final e in exercise.equipmentLabels) {
      chips.add(_MetaChip(icon: LucideIcons.dumbbell, text: e));
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Wrap(spacing: 12, runSpacing: 6, children: chips),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: () => _openVideo(context, exercise),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.accent,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: const Icon(LucideIcons.playCircle, size: 16),
          label: const Text('Техника', style: TextStyle(fontSize: 13)),
        ),
      ],
    );
  }
}

Future<void> _openVideo(BuildContext context, Exercise ex) async {
  final uri = Uri.tryParse(ex.videoUrlOrSearch);
  if (uri == null) return;
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Не удалось открыть видео')),
    );
  }
}

/// A logged-set chip; tapping opens the edit/delete sheet. [#6]
class _LoggedPill extends StatelessWidget {
  final LoggedSet set;
  final VoidCallback onTap;
  const _LoggedPill({required this.set, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.green.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_formatKg(set.weightG)} × ${set.reps}',
                style: const TextStyle(
                    color: AppColors.green,
                    fontWeight: FontWeight.w600,
                    fontSize: 12),
              ),
              const SizedBox(width: 4),
              Icon(Icons.edit,
                  size: 11, color: AppColors.green.withValues(alpha: 0.8)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Numeric input dialog (tap-to-type on a stepper). Returns null on cancel. [#4]
Future<double?> _promptNumber(
  BuildContext context, {
  required String title,
  required double initial,
  required bool allowDecimal,
}) {
  final text = allowDecimal
      ? (initial == initial.roundToDouble()
          ? initial.toStringAsFixed(0)
          : initial.toString())
      : initial.round().toString();
  final controller = TextEditingController(text: text);
  return showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType:
            TextInputType.numberWithOptions(decimal: allowDecimal, signed: false),
        inputFormatters: [
          FilteringTextInputFormatter.allow(
            allowDecimal ? RegExp(r'[0-9.,]') : RegExp(r'[0-9]'),
          ),
        ],
        decoration: const InputDecoration(border: OutlineInputBorder()),
        onSubmitted: (_) => _submitNumber(ctx, controller.text),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => _submitNumber(ctx, controller.text),
          child: const Text('ОК'),
        ),
      ],
    ),
  );
}

void _submitNumber(BuildContext ctx, String raw) {
  final v = double.tryParse(raw.replaceAll(',', '.'));
  Navigator.of(ctx).pop(v);
}

void _editLoggedSet(
  BuildContext context,
  WorkoutCubit cubit,
  Exercise ex,
  String reId,
  int index,
  LoggedSet set,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _EditLoggedSetSheet(
      cubit: cubit,
      exercise: ex,
      reId: reId,
      index: index,
      set: set,
    ),
  );
}

class _EditLoggedSetSheet extends StatefulWidget {
  final WorkoutCubit cubit;
  final Exercise exercise;
  final String reId;
  final int index;
  final LoggedSet set;
  const _EditLoggedSetSheet({
    required this.cubit,
    required this.exercise,
    required this.reId,
    required this.index,
    required this.set,
  });

  @override
  State<_EditLoggedSetSheet> createState() => _EditLoggedSetSheetState();
}

class _EditLoggedSetSheetState extends State<_EditLoggedSetSheet> {
  late int _weightG = widget.set.weightG;
  late int _reps = widget.set.reps;
  late int? _rir = widget.set.rir;

  @override
  Widget build(BuildContext context) {
    final inc = widget.exercise.minIncrementG > 0
        ? widget.exercise.minIncrementG
        : 2500;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Подход ${widget.index + 1} · ${widget.exercise.displayName}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SetStepper(
                  label: widget.exercise.isDumbbell
                      ? 'Вес, кг (одна гантель)'
                      : 'Вес, кг',
                  value: _formatKg(_weightG),
                  onMinus: () => setState(
                      () => _weightG = (_weightG - inc).clamp(0, 1 << 30)),
                  onPlus: () => setState(
                      () => _weightG = (_weightG + inc).clamp(0, 1 << 30)),
                  onTapValue: () async {
                    final kg = await _promptNumber(context,
                        title: 'Вес, кг',
                        initial: _weightG / 1000,
                        allowDecimal: true);
                    if (kg != null) setState(() => _weightG = (kg * 1000).round());
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SetStepper(
                  label: 'Повторы',
                  value: '$_reps',
                  onMinus: () => setState(() => _reps = (_reps - 1).clamp(0, 999)),
                  onPlus: () => setState(() => _reps = (_reps + 1).clamp(0, 999)),
                  onTapValue: () async {
                    final n = await _promptNumber(context,
                        title: 'Повторы',
                        initial: _reps.toDouble(),
                        allowDecimal: false);
                    if (n != null) setState(() => _reps = n.round());
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SetStepper(
                  label: 'RIR',
                  value: _rir?.toString() ?? '—',
                  onMinus: () => setState(
                      () => _rir = _rir == null ? null : (_rir! - 1).clamp(0, 20)),
                  onPlus: () =>
                      setState(() => _rir = ((_rir ?? -1) + 1).clamp(0, 20)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  widget.cubit.deleteLoggedSet(widget.reId, widget.index);
                  Navigator.of(context).pop();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                ),
                icon: const Icon(LucideIcons.trash2, size: 18),
                label: const Text('Удалить'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    widget.cubit.editLoggedSet(
                      widget.reId,
                      widget.index,
                      weightG: _weightG,
                      reps: _reps,
                      rir: _rir,
                      clearRir: _rir == null,
                    );
                    Navigator.of(context).pop();
                  },
                  child: const Text('Сохранить'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
