import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../app/theme.dart';
import '../../../core/di/di.dart';
import '../../../core/network/api_client.dart';
import '../cubit/program_cubit.dart';
import '../data/program_models.dart';
import '../data/program_repository.dart';

/// KEEP this class name — the router imports it (`/workout/program`).
class ProgramPage extends StatelessWidget {
  const ProgramPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => ProgramCubit(ProgramRepository(sl<ApiClient>()))..load(),
        child: const _ProgramView(),
      );
}

class _ProgramView extends StatelessWidget {
  const _ProgramView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: BlocConsumer<ProgramCubit, ProgramState>(
          listenWhen: (a, b) =>
              a.error != b.error && b.error != null && !b.unauthorized,
          listener: (context, state) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(state.error!)));
          },
          builder: (context, state) {
            switch (state.status) {
              case ProgramStatus.initial:
              case ProgramStatus.loading:
                return const Center(child: CircularProgressIndicator());
              case ProgramStatus.error:
                return _ErrorView(state: state);
              case ProgramStatus.ready:
                return _Content(state: state);
            }
          },
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final ProgramState state;
  const _ErrorView({required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProgramCubit>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              state.unauthorized ? LucideIcons.keyRound : LucideIcons.wifiOff,
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
  final ProgramState state;
  const _Content({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.routines.isEmpty) {
      return const _EmptyView();
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Text('Программа', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(
          _programSubtitle(state.routines.length),
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
        ),
        const SizedBox(height: 16),
        for (final routine in state.routines) ...[
          _RoutineCard(state: state, routine: routine),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 4),
        _CreateRoutineButton(),
      ],
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.clipboardList,
                size: 40, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text('Пока нет тренировок',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Здесь появятся ваши тренировки программы.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutineCard extends StatelessWidget {
  final ProgramState state;
  final Routine routine;
  const _RoutineCard({required this.state, required this.routine});

  @override
  Widget build(BuildContext context) {
    final expanded = state.expandedRoutines.contains(routine.id);
    final loading = state.loadingRoutines.contains(routine.id);
    final items = state.composition[routine.id];

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppRadii.card),
            onTap: () => context.read<ProgramCubit>().toggleRoutine(routine.id),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _Badge(letter: routine.badge),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          routine.displayName,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontSize: 19),
                        ),
                        if ((routine.notes ?? '').isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            routine.notes!,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (items == null || items.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Text(
                  'В этой тренировке пока нет упражнений.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            else
              _Composition(state: state, routine: routine, items: items),
          ],
        ],
      ),
    );
  }
}

class _Composition extends StatelessWidget {
  final ProgramState state;
  final Routine routine;
  final List<ProgramExercise> items;
  const _Composition({
    required this.state,
    required this.routine,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[];
    for (final section in kSectionOrder) {
      final sectionItems =
          items.where((e) => e.section == section).toList();
      if (sectionItems.isEmpty) continue;
      if (sections.isNotEmpty) {
        sections.add(const Divider(height: 1));
      }
      sections.add(_SectionBlock(
        routine: routine,
        section: section,
        items: sectionItems,
        expanded: state.expandedSections.contains('${routine.id}::$section'),
        state: state,
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: sections);
  }
}

class _SectionMeta {
  final String label;
  final Color color;
  const _SectionMeta(this.label, this.color);
}

_SectionMeta _sectionMeta(String section) {
  switch (section) {
    case 'warmup':
      return const _SectionMeta('РАЗМИНКА', AppColors.amber);
    case 'reab':
      return const _SectionMeta('РЕАБ-БЛОК', AppColors.danger);
    case 'main':
    default:
      return const _SectionMeta('ОСНОВНАЯ', AppColors.accent);
  }
}

class _SectionBlock extends StatelessWidget {
  final Routine routine;
  final String section;
  final List<ProgramExercise> items;
  final bool expanded;
  final ProgramState state;
  const _SectionBlock({
    required this.routine,
    required this.section,
    required this.items,
    required this.expanded,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final meta = _sectionMeta(section);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () =>
              context.read<ProgramCubit>().toggleSection(routine.id, section),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Text(
                  meta.label,
                  style: TextStyle(
                    color: meta.color,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.6,
                  ),
                ),
                const Spacer(),
                Text(
                  _exerciseCount(items.length),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          for (final item in items)
            _ExerciseRow(
              name: state.exerciseName(item.exerciseId),
              target: item.targetLabel,
            ),
      ],
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  final String name;
  final String target;
  const _ExerciseRow({required this.name, required this.target});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          const Icon(LucideIcons.gripVertical,
              size: 18, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  target,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String letter;
  const _Badge({required this.letter});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(AppRadii.inner),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
      ),
    );
  }
}

class _CreateRoutineButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accentSoft,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.card),
        onTap: () {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(
                content: Text('Редактирование программы скоро')));
        },
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.plus, size: 20, color: AppColors.accent),
              SizedBox(width: 8),
              Text(
                'Новая тренировка',
                style: TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- Russian pluralization helpers ----------

String _plural(int n, String one, String few, String many) {
  final mod100 = n % 100;
  final mod10 = n % 10;
  if (mod100 >= 11 && mod100 <= 14) return many;
  if (mod10 == 1) return one;
  if (mod10 >= 2 && mod10 <= 4) return few;
  return many;
}

String _programSubtitle(int count) =>
    '$count ${_plural(count, 'тренировка', 'тренировки', 'тренировок')}';

String _exerciseCount(int count) =>
    '$count ${_plural(count, 'упражнение', 'упражнения', 'упражнений')}';
