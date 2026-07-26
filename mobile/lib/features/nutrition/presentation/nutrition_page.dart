import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../app/theme.dart';
import '../../../core/di/di.dart';
import '../../../core/network/api_client.dart';
import '../cubit/nutrition_cubit.dart';
import '../data/nutrition_models.dart';
import '../data/nutrition_repository.dart';
import 'widgets/quick_log_sheet.dart';

class NutritionPage extends StatelessWidget {
  const NutritionPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) =>
            NutritionCubit(NutritionRepository(sl<ApiClient>()))..load(),
        child: const _NutritionView(),
      );
}

// ── Meal display metadata (API seeds English names; map to RU + icon) ─────────

class _MealMeta {
  final String label;
  final IconData icon;
  final Color color;
  const _MealMeta(this.label, this.icon, this.color);
}

const _mealMeta = <String, _MealMeta>{
  'meal-breakfast': _MealMeta('Завтрак', LucideIcons.sunrise, AppColors.amber),
  'meal-lunch': _MealMeta('Обед', LucideIcons.sun, AppColors.accent),
  'meal-dinner': _MealMeta('Ужин', LucideIcons.moon, AppColors.sleep),
  'meal-snack': _MealMeta('Перекус', LucideIcons.cookie, AppColors.green),
};

_MealMeta _metaFor(MealGroup m) =>
    _mealMeta[m.mealId] ?? _MealMeta(m.mealName, LucideIcons.utensils, AppColors.accent);

// ── View ──────────────────────────────────────────────────────────────────

class _NutritionView extends StatelessWidget {
  const _NutritionView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<NutritionCubit, NutritionState>(
          builder: (context, state) {
            switch (state.status) {
              case NutritionStatus.initial:
              case NutritionStatus.loading:
                return const Center(child: CircularProgressIndicator());
              case NutritionStatus.error:
                return _ErrorView(
                  state: state,
                  onRetry: () => context.read<NutritionCubit>().load(),
                );
              case NutritionStatus.ready:
                return _Content(data: state.data!);
            }
          },
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  final NutritionDay data;
  const _Content({required this.data});

  Future<void> _add(BuildContext context, {String mealId = 'meal-breakfast'}) async {
    final input = await showQuickLogSheet(context, initialMealId: mealId);
    if (input != null && context.mounted) {
      await context.read<NutritionCubit>().quickLog(input);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => context.read<NutritionCubit>().load(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _Header(onAdd: () => _add(context)),
          const SizedBox(height: 16),
          _TotalsCard(day: data),
          const SizedBox(height: 16),
          for (final meal in data.meals) ...[
            _MealCard(
              meal: meal,
              onAdd: () => _add(context, mealId: meal.mealId),
              onDelete: (id) => context.read<NutritionCubit>().deleteEntry(id),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final VoidCallback onAdd;
  const _Header({required this.onAdd});

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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Питание',
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
        Material(
          color: AppColors.accent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onAdd,
            child: const SizedBox(
              width: 52,
              height: 52,
              child: Icon(LucideIcons.plus, color: Colors.white, size: 26),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Totals card ───────────────────────────────────────────────────────────────

class _TotalsCard extends StatelessWidget {
  final NutritionDay day;
  const _TotalsCard({required this.day});

  @override
  Widget build(BuildContext context) {
    final t = day.totals;
    final target = day.target;
    final consumed = t.calories;
    final targetCals = target?.calories ?? 0;
    final remaining = day.remainingCalories;
    final progress = targetCals > 0 ? (consumed / targetCals).clamp(0.0, 1.0) : 0.0;

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Съедено',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(_group(consumed),
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            target != null ? '/ ${_group(targetCals)} ккал' : 'ккал',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (remaining != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Осталось',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 2),
                    Text(_group(remaining),
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              color: remaining < 0
                                  ? AppColors.danger
                                  : AppColors.accent,
                              fontWeight: FontWeight.w700,
                            )),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation(AppColors.accent),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _MacroBar(
                  label: 'Белки',
                  consumedG: t.proteinG,
                  targetG: target?.proteinG,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _MacroBar(
                  label: 'Жиры',
                  consumedG: t.fatG,
                  targetG: target?.fatG,
                  color: AppColors.amber,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _MacroBar(
                  label: 'Углеводы',
                  consumedG: t.carbsG,
                  targetG: target?.carbsG,
                  color: AppColors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroBar extends StatelessWidget {
  final String label;
  final int consumedG;
  final int? targetG;
  final Color color;
  const _MacroBar({
    required this.label,
    required this.consumedG,
    required this.targetG,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tg = targetG;
    final fill = (tg != null && tg > 0) ? (consumedG / tg).clamp(0.0, 1.0) : 0.0;
    final valueText = (tg != null && tg > 0) ? '$consumedG / $tg г' : '$consumedG г';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary)),
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
        const SizedBox(height: 6),
        Text(valueText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textMuted)),
      ],
    );
  }
}

// ── Meal card ─────────────────────────────────────────────────────────────────

class _MealCard extends StatelessWidget {
  final MealGroup meal;
  final VoidCallback onAdd;
  final void Function(String id) onDelete;
  const _MealCard({
    required this.meal,
    required this.onAdd,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final meta = _metaFor(meal);
    final empty = meal.entries.isEmpty;

    return _Panel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: meta.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadii.inner),
                  ),
                  child: Icon(meta.icon, size: 22, color: meta.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(meta.label,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(_positionsLabel(meal.entries.length),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.textMuted)),
                    ],
                  ),
                ),
                if (!empty) ...[
                  Text('${_group(meal.totalCalories)} ккал',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                ],
                _AddButton(onTap: onAdd),
              ],
            ),
          ),
          if (empty)
            _AddRow(onTap: onAdd)
          else
            for (final e in meal.entries) _EntryRow(entry: e, onDelete: onDelete),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 36,
          height: 36,
          child: Icon(LucideIcons.plus, size: 20, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _AddRow extends StatelessWidget {
  final VoidCallback onTap;
  const _AddRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(height: 1),
        InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(AppRadii.card),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Icon(LucideIcons.plus, size: 18, color: AppColors.accent),
                const SizedBox(width: 8),
                Text('Добавить продукт',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                        )),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EntryRow extends StatelessWidget {
  final FoodEntry entry;
  final void Function(String id) onDelete;
  const _EntryRow({required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(height: 1),
        Dismissible(
          key: ValueKey(entry.id),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => onDelete(entry.id),
          background: Container(
            color: AppColors.dangerSoft,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Icon(LucideIcons.trash2, color: AppColors.danger),
          ),
          child: Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        '${entry.servingGrams} г · Б·${entry.proteinG} Ж·${entry.fatG} У·${entry.carbsG}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _group(entry.calories),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ],
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

/// Group thousands with a thin space (Russian style): 2150 → "2 150".
String _group(int value) {
  final neg = value < 0;
  final digits = value.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(' ');
    buf.write(digits[i]);
  }
  return neg ? '-${buf.toString()}' : buf.toString();
}

/// Russian pluralization for "позиция".
String _positionsLabel(int n) {
  if (n == 0) return 'ничего не добавлено';
  final mod100 = n % 100;
  final mod10 = n % 10;
  String word;
  if (mod100 >= 11 && mod100 <= 14) {
    word = 'позиций';
  } else if (mod10 == 1) {
    word = 'позиция';
  } else if (mod10 >= 2 && mod10 <= 4) {
    word = 'позиции';
  } else {
    word = 'позиций';
  }
  return '$n $word';
}

class _ErrorView extends StatelessWidget {
  final NutritionState state;
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
