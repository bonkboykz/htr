import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme.dart';
import '../../../core/di/di.dart';
import '../../../core/network/api_client.dart';
import '../cubit/factors_cubit.dart';
import '../data/factors_models.dart';
import '../data/factors_repository.dart';
import 'widgets/add_factor_sheet.dart';
import 'widgets/factor_controls.dart';

/// Opens the "new factor" bottom sheet, wired to the current [FactorsCubit].
Future<void> showAddFactorSheet(BuildContext context, {String? categoryId}) {
  final cubit = context.read<FactorsCubit>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.card)),
    ),
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: AddFactorSheet(defaultCategoryId: categoryId),
    ),
  );
}

/// Confirms then soft-deletes a factor via the cubit.
Future<void> confirmDeleteFactor(BuildContext context, Factor factor) async {
  final cubit = context.read<FactorsCubit>();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Удалить фактор?'),
      content: Text('«${factor.name}» будет удалён из списка.'),
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
  if (ok == true) await cubit.deleteFactor(factor.id);
}

/// Full-screen route reached from Today (`/today/factors`).
class FactorsPage extends StatelessWidget {
  const FactorsPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => FactorsCubit(FactorsRepository(sl<ApiClient>()))..load(),
        child: const _FactorsView(),
      );
}

class _FactorsView extends StatelessWidget {
  const _FactorsView();

  static const _weekdays = [
    'понедельник', 'вторник', 'среда', 'четверг', 'пятница', 'суббота',
    'воскресенье',
  ];
  static const _months = [
    'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
    'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
  ];

  String _dateStr() {
    final now = DateTime.now();
    return '${_weekdays[now.weekday - 1]}, ${now.day} ${_months[now.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.canPop() ? context.pop() : null,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Факторы',
                style: TextStyle(fontWeight: FontWeight.w700)),
            Text(
              _dateStr(),
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(LucideIcons.plus),
              tooltip: 'Добавить фактор',
              onPressed: () => showAddFactorSheet(context),
            ),
          ),
        ],
      ),
      body: BlocConsumer<FactorsCubit, FactorsState>(
        listenWhen: (a, b) =>
            a.savedMessage != b.savedMessage ||
            (a.error != b.error && b.error != null && !b.unauthorized),
        listener: (context, state) {
          if (state.savedMessage != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: Text(state.savedMessage!),
                backgroundColor: AppColors.accent,
                behavior: SnackBarBehavior.floating,
              ));
          } else if (state.error != null && !state.unauthorized) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(state.error!)));
          }
        },
        builder: (context, state) {
          switch (state.status) {
            case FactorsStatus.initial:
            case FactorsStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case FactorsStatus.error:
              return _ErrorView(state: state);
            case FactorsStatus.ready:
              return _Content(state: state);
          }
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final FactorsState state;
  const _ErrorView({required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<FactorsCubit>();
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
  final FactorsState state;
  const _Content({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.groups.every((g) => g.factors.isEmpty)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Факторы пока не заданы.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => showAddFactorSheet(context),
                icon: const Icon(LucideIcons.plus, size: 20),
                label: const Text('Добавить фактор'),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              for (final group in state.groups)
                if (group.factors.isNotEmpty) ...[
                  _CategoryCard(group: group, values: state.values),
                  const SizedBox(height: 16),
                ],
            ],
          ),
        ),
        _SaveBar(state: state),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final FactorGroup group;
  final Map<String, int> values;
  const _CategoryCard({required this.group, required this.values});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                group.category.emoji ?? '•',
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  group.category.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final f in group.factors)
            FactorRow(
              factor: f.factor,
              value: values[f.factor.id],
              onDelete: () => confirmDeleteFactor(context, f.factor),
            ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () =>
                  showAddFactorSheet(context, categoryId: group.category.id),
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text('Добавить фактор'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  final FactorsState state;
  const _SaveBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<FactorsCubit>();
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: FilledButton.icon(
        onPressed: state.saving ? null : () => cubit.save(),
        icon: state.saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(LucideIcons.check, size: 20),
        label: const Text('Сохранить'),
      ),
    );
  }
}
