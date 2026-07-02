import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../app/theme.dart';
import '../../../core/di/di.dart';
import '../../../core/network/api_client.dart';
import '../cubit/session_detail_cubit.dart';
import '../data/workout_models.dart';
import '../data/workout_repository.dart';
import 'widgets/set_stepper.dart';

const _months = [
  'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
  'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
];

String _formatDate(String iso) {
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return iso;
  return '${d.day} ${_months[d.month - 1]}';
}

String _formatKg(int grams) {
  final kg = grams / 1000;
  final s = kg.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

class SessionDetailPage extends StatelessWidget {
  final String sessionId;
  const SessionDetailPage({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) =>
            SessionDetailCubit(WorkoutRepository(sl<ApiClient>()), sessionId)
              ..load(),
        child: const _SessionDetailView(),
      );
}

class _SessionDetailView extends StatelessWidget {
  const _SessionDetailView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SessionDetailCubit, SessionDetailState>(
      listenWhen: (a, b) =>
          a.deleted != b.deleted ||
          (a.error != b.error && b.error != null && !b.unauthorized),
      listener: (context, state) {
        if (state.deleted) {
          context.pop();
        } else if (state.error != null && !state.unauthorized) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(state.error!)));
        }
      },
      builder: (context, state) {
        final detail = state.detail;
        final title = detail == null
            ? 'Тренировка'
            : '${detail.routineName.isEmpty ? 'Тренировка' : detail.routineName}'
                ' · ${_formatDate(detail.startedAt)}';
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(LucideIcons.arrowLeft, size: 22),
              onPressed: () => context.pop(),
            ),
            title: Text(title, style: const TextStyle(fontSize: 17)),
            actions: [
              if (detail != null)
                IconButton(
                  icon: const Icon(LucideIcons.trash2,
                      size: 20, color: AppColors.danger),
                  onPressed: () => _confirmDeleteSession(context),
                ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: _body(context, state),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, SessionDetailState state) {
    switch (state.status) {
      case SessionDetailStatus.initial:
      case SessionDetailStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case SessionDetailStatus.error:
        return _ErrorView(state: state);
      case SessionDetailStatus.ready:
        return _Content(detail: state.detail!);
    }
  }

  Future<void> _confirmDeleteSession(BuildContext context) async {
    final cubit = context.read<SessionDetailCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить тренировку?'),
        content: const Text(
          'Тренировка и все её подходы будут удалены.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
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
    if (ok == true) cubit.deleteSession();
  }
}

class _ErrorView extends StatelessWidget {
  final SessionDetailState state;
  const _ErrorView({required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SessionDetailCubit>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              state.unauthorized ? LucideIcons.keyRound : LucideIcons.alertCircle,
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
  final SessionDetail detail;
  const _Content({required this.detail});

  @override
  Widget build(BuildContext context) {
    // Group sets by exerciseName, preserving first-seen order.
    final order = <String>[];
    final groups = <String, List<SessionSet>>{};
    for (final s in detail.sets) {
      final key = s.exerciseName;
      if (!groups.containsKey(key)) {
        order.add(key);
        groups[key] = [];
      }
      groups[key]!.add(s);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _SummaryCard(detail: detail),
        const SizedBox(height: 20),
        if (order.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('В этой тренировке нет подходов.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
          )
        else
          for (final name in order) ...[
            _ExerciseGroup(name: name, sets: groups[name]!),
            const SizedBox(height: 16),
          ],
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final SessionDetail detail;
  const _SummaryCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Занятие ${detail.sessionIndex} · ${_formatDate(detail.startedAt)}',
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _Stat(
                label: 'Длительность',
                value: detail.durationFormatted ?? '—',
              ),
              _Stat(label: 'Объём', value: detail.volumeFormatted),
              _Stat(label: 'Подходов', value: '${detail.totalSets}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ExerciseGroup extends StatelessWidget {
  final String name;
  final List<SessionSet> sets;
  const _ExerciseGroup({required this.name, required this.sets});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                if (sets.any((s) => s.isWarmup))
                  const Text('размин.',
                      style: TextStyle(
                          color: AppColors.amber,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          for (var i = 0; i < sets.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.border),
            _SetRow(set: sets[i]),
          ],
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  final SessionSet set;
  const _SetRow({required this.set});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openEditSheet(context, set),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text('#${set.setNumber}',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 13)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${set.weightFormatted} × ${set.reps}',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              set.rir != null ? 'RIR ${set.rir}' : '—',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(width: 10),
            const Icon(LucideIcons.pencil, size: 16, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  void _openEditSheet(BuildContext context, SessionSet set) {
    final cubit = context.read<SessionDetailCubit>();
    final increment = cubit.state.incrementFor(set.exerciseId);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.card)),
      ),
      builder: (sheetCtx) => _EditSetSheet(
        set: set,
        increment: increment,
        onSave: (weightG, reps, rir) {
          Navigator.of(sheetCtx).pop();
          cubit.editSet(set.id, weightG: weightG, reps: reps, rir: rir);
        },
        onDelete: () {
          Navigator.of(sheetCtx).pop();
          cubit.deleteSet(set.id);
        },
      ),
    );
  }
}

class _EditSetSheet extends StatefulWidget {
  final SessionSet set;
  final int increment;
  final void Function(int weightG, int reps, int? rir) onSave;
  final VoidCallback onDelete;

  const _EditSetSheet({
    required this.set,
    required this.increment,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<_EditSetSheet> createState() => _EditSetSheetState();
}

class _EditSetSheetState extends State<_EditSetSheet> {
  late int _weightG;
  late int _reps;
  int? _rir;

  @override
  void initState() {
    super.initState();
    _weightG = widget.set.weightG;
    _reps = widget.set.reps;
    _rir = widget.set.rir;
  }

  void _stepWeight(int delta) =>
      setState(() => _weightG = (_weightG + delta).clamp(0, 1 << 30));
  void _stepReps(int delta) =>
      setState(() => _reps = (_reps + delta).clamp(0, 999));
  void _stepRir(int delta) {
    setState(() {
      if (delta > 0) {
        _rir = ((_rir ?? -1) + 1).clamp(0, 20);
      } else if (_rir != null) {
        final next = _rir! - 1;
        _rir = next < 0 ? null : next;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${widget.set.exerciseName} · подход ${widget.set.setNumber}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.trash2,
                    size: 20, color: AppColors.danger),
                onPressed: widget.onDelete,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SetStepper(
            label: 'Вес, кг',
            value: _formatKg(_weightG),
            onMinus: () => _stepWeight(-widget.increment),
            onPlus: () => _stepWeight(widget.increment),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SetStepper(
                  label: 'Повторы',
                  value: '$_reps',
                  onMinus: () => _stepReps(-1),
                  onPlus: () => _stepReps(1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SetStepper(
                  label: 'RIR',
                  value: _rir?.toString() ?? '—',
                  onMinus: () => _stepRir(-1),
                  onPlus: () => _stepRir(1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => widget.onSave(_weightG, _reps, _rir),
              icon: const Icon(LucideIcons.check, size: 20),
              label: const Text('Сохранить'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
