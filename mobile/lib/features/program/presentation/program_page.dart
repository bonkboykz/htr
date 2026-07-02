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
                return Stack(
                  children: [
                    _Content(state: state),
                    if (state.mutating) const _MutationOverlay(),
                  ],
                );
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
                  _RoutineMenu(routine: routine),
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
            else ...[
              if (items == null || items.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'В этой тренировке пока нет упражнений.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              else
                _Composition(state: state, routine: routine, items: items),
              _AddExerciseRow(routine: routine),
            ],
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
              routine: routine,
              item: item,
              name: state.exerciseName(item.exerciseId),
              target: item.targetLabel,
            ),
      ],
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  final Routine routine;
  final ProgramExercise item;
  final String name;
  final String target;
  const _ExerciseRow({
    required this.routine,
    required this.item,
    required this.name,
    required this.target,
  });

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProgramCubit>();
    return InkWell(
      onTap: () => _showExerciseSheet(
        context,
        cubit,
        routineId: routine.id,
        existing: item,
      ),
      child: Padding(
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
            IconButton(
              icon: const Icon(LucideIcons.trash2, size: 18),
              color: AppColors.textMuted,
              tooltip: 'Удалить',
              onPressed: () async {
                final ok = await _confirm(
                  context,
                  title: 'Удалить упражнение?',
                  message: '«$name» будет удалено из тренировки.',
                );
                if (ok) cubit.deleteExercise(routine.id, item.id);
              },
            ),
          ],
        ),
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
        onTap: () =>
            _showRoutineDialog(context, context.read<ProgramCubit>()),
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

// ---------- CRUD affordances ----------

class _MutationOverlay extends StatelessWidget {
  const _MutationOverlay();

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: ColoredBox(
        color: Color(0x66F6F7F9),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _RoutineMenu extends StatelessWidget {
  final Routine routine;
  const _RoutineMenu({required this.routine});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProgramCubit>();
    return PopupMenuButton<String>(
      icon: const Icon(LucideIcons.moreVertical,
          color: AppColors.textSecondary, size: 20),
      onSelected: (value) async {
        switch (value) {
          case 'edit':
            await _showRoutineDialog(context, cubit, routine: routine);
            break;
          case 'delete':
            final ok = await _confirm(
              context,
              title: 'Удалить тренировку?',
              message:
                  '«${routine.displayName}» и все её упражнения будут удалены.',
            );
            if (ok) cubit.deleteRoutine(routine.id);
            break;
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'edit', child: Text('Изменить')),
        PopupMenuItem(value: 'delete', child: Text('Удалить')),
      ],
    );
  }
}

class _AddExerciseRow extends StatelessWidget {
  final Routine routine;
  const _AddExerciseRow({required this.routine});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProgramCubit>();
    return InkWell(
      onTap: () => _showExerciseSheet(context, cubit, routineId: routine.id),
      child: const Padding(
        padding: EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Row(
          children: [
            Icon(LucideIcons.plus, size: 18, color: AppColors.accent),
            SizedBox(width: 8),
            Text(
              'упражнение',
              style: TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Удалить'),
        ),
      ],
    ),
  );
  return res == true;
}

Future<void> _showRoutineDialog(
  BuildContext context,
  ProgramCubit cubit, {
  Routine? routine,
}) async {
  final isEdit = routine != null;
  final nameCtrl = TextEditingController(text: routine?.displayName ?? '');
  final notesCtrl = TextEditingController(text: routine?.notes ?? '');

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(isEdit ? 'Изменить тренировку' : 'Новая тренировка'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Название'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: notesCtrl,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration:
                const InputDecoration(labelText: 'Заметки (необязательно)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            if (nameCtrl.text.trim().isEmpty) return;
            Navigator.of(ctx).pop(true);
          },
          child: Text(isEdit ? 'Сохранить' : 'Создать'),
        ),
      ],
    ),
  );

  if (saved != true) return;
  final name = nameCtrl.text.trim();
  final notes = notesCtrl.text.trim();
  if (isEdit) {
    await cubit.updateRoutine(routine.id, nameRu: name, notes: notes);
  } else {
    await cubit.createRoutine(
        nameRu: name, notes: notes.isEmpty ? null : notes);
  }
}

class _ExerciseFormResult {
  final String exerciseId;
  final String section;
  final int targetSets;
  final int repMin;
  final int repMax;
  final int targetRir;
  const _ExerciseFormResult({
    required this.exerciseId,
    required this.section,
    required this.targetSets,
    required this.repMin,
    required this.repMax,
    required this.targetRir,
  });
}

Future<void> _showExerciseSheet(
  BuildContext context,
  ProgramCubit cubit, {
  required String routineId,
  ProgramExercise? existing,
}) async {
  await cubit.loadCatalog();
  if (!context.mounted) return;
  final state = cubit.state;
  final result = await showModalBottomSheet<_ExerciseFormResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.card)),
    ),
    builder: (_) => _ExerciseSheet(
      catalog: state.catalog,
      existing: existing,
      initialName: existing != null
          ? state.exerciseName(existing.exerciseId)
          : null,
    ),
  );
  if (result == null) return;
  if (existing == null) {
    await cubit.addExercise(
      routineId,
      exerciseId: result.exerciseId,
      section: result.section,
      targetSets: result.targetSets,
      repMin: result.repMin,
      repMax: result.repMax,
      targetRir: result.targetRir,
    );
  } else {
    await cubit.updateExercise(
      routineId,
      existing.id,
      exerciseId: result.exerciseId,
      section: result.section,
      targetSets: result.targetSets,
      repMin: result.repMin,
      repMax: result.repMax,
      targetRir: result.targetRir,
    );
  }
}

class _ExerciseSheet extends StatefulWidget {
  final List<ProgramCatalogExercise> catalog;
  final ProgramExercise? existing;
  final String? initialName;
  const _ExerciseSheet({
    required this.catalog,
    this.existing,
    this.initialName,
  });

  @override
  State<_ExerciseSheet> createState() => _ExerciseSheetState();
}

class _ExerciseSheetState extends State<_ExerciseSheet> {
  String? _exerciseId;
  String? _exerciseName;
  late String _section;
  late int _sets;
  late int _repMin;
  late int _repMax;
  late int _rir;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _exerciseId = ex?.exerciseId;
    _exerciseName = widget.initialName;
    _section = ex?.section ?? 'main';
    _sets = ex?.targetSets ?? 3;
    _repMin = ex?.repMin ?? 8;
    _repMax = ex?.repMax ?? 12;
    _rir = ex?.targetRir ?? 2;
  }

  bool get _valid =>
      _exerciseId != null && _repMin >= 1 && _repMax >= _repMin && _sets >= 1;

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isEdit ? 'Изменить упражнение' : 'Добавить упражнение',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            InkWell(
              borderRadius: BorderRadius.circular(AppRadii.inner),
              onTap: _pickExercise,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppRadii.inner),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.dumbbell,
                        size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _exerciseName ?? 'Выберите упражнение',
                        style: TextStyle(
                          fontSize: 16,
                          color: _exerciseName == null
                              ? AppColors.textMuted
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const Icon(LucideIcons.chevronRight,
                        size: 18, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Секция',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [for (final s in kSectionOrder) _sectionChip(s)],
            ),
            const SizedBox(height: 8),
            _StepperRow(
              label: 'Подходы',
              value: _sets,
              min: 1,
              max: 12,
              onChanged: (v) => setState(() => _sets = v),
            ),
            _StepperRow(
              label: 'Повторы (мин)',
              value: _repMin,
              min: 1,
              max: 60,
              onChanged: (v) => setState(() {
                _repMin = v;
                if (_repMax < _repMin) _repMax = _repMin;
              }),
            ),
            _StepperRow(
              label: 'Повторы (макс)',
              value: _repMax,
              min: _repMin,
              max: 60,
              onChanged: (v) => setState(() => _repMax = v),
            ),
            _StepperRow(
              label: 'RIR',
              value: _rir,
              min: 0,
              max: 5,
              onChanged: (v) => setState(() => _rir = v),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _valid
                  ? () => Navigator.of(context).pop(
                        _ExerciseFormResult(
                          exerciseId: _exerciseId!,
                          section: _section,
                          targetSets: _sets,
                          repMin: _repMin,
                          repMax: _repMax,
                          targetRir: _rir,
                        ),
                      )
                  : null,
              child: Text(isEdit ? 'Сохранить' : 'Добавить'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickExercise() async {
    final picked = await showModalBottomSheet<ProgramCatalogExercise>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadii.card)),
      ),
      builder: (_) => _ExercisePicker(catalog: widget.catalog),
    );
    if (picked != null) {
      setState(() {
        _exerciseId = picked.id;
        _exerciseName = picked.displayName;
      });
    }
  }

  Widget _sectionChip(String s) {
    final meta = _sectionMeta(s);
    final selected = _section == s;
    return ChoiceChip(
      label: Text(meta.label),
      selected: selected,
      onSelected: (_) => setState(() => _section = s),
      showCheckmark: false,
      labelStyle: TextStyle(
        color: selected ? Colors.white : meta.color,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      selectedColor: meta.color,
      backgroundColor: AppColors.surface,
      side: BorderSide(color: meta.color),
    );
  }
}

class _StepperRow extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  const _StepperRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 15, color: AppColors.textPrimary)),
          ),
          _RoundIconButton(
            icon: LucideIcons.minus,
            onTap: value > min ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 44,
            child: Text('$value',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ),
          _RoundIconButton(
            icon: LucideIcons.plus,
            onTap: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: enabled ? AppColors.accentSoft : AppColors.bg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon,
              size: 18,
              color: enabled ? AppColors.accent : AppColors.textMuted),
        ),
      ),
    );
  }
}

class _ExercisePicker extends StatefulWidget {
  final List<ProgramCatalogExercise> catalog;
  const _ExercisePicker({required this.catalog});

  @override
  State<_ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends State<_ExercisePicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final query = _q.trim().toLowerCase();
    final items = query.isEmpty
        ? widget.catalog
        : widget.catalog
            .where((e) =>
                e.displayName.toLowerCase().contains(query) ||
                e.name.toLowerCase().contains(query))
            .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _q = v),
                decoration: InputDecoration(
                  hintText: 'Поиск упражнения',
                  prefixIcon: const Icon(LucideIcons.search, size: 18),
                  filled: true,
                  fillColor: AppColors.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.inner),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const Center(
                      child: Text('Ничего не найдено',
                          style: TextStyle(color: AppColors.textSecondary)),
                    )
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final e = items[i];
                        return ListTile(
                          title: Text(e.displayName),
                          subtitle: e.muscleGroup != null
                              ? Text(e.muscleGroup!)
                              : null,
                          onTap: () => Navigator.of(context).pop(e),
                        );
                      },
                    ),
            ),
          ],
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
