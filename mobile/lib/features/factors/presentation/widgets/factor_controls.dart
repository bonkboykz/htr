import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../app/theme.dart';
import '../../cubit/factors_cubit.dart';
import '../../data/factors_models.dart';

/// One factor row: label + kind-appropriate control.
/// `kind == "rating"` → a row of value chips.
/// `kind == "count"`  → a −/value/+ stepper (no upper cap).
class FactorRow extends StatelessWidget {
  final Factor factor;
  final int? value;

  /// When non-null, a long-press or trailing overflow lets the user delete
  /// this factor (the callback runs after its own confirm dialog).
  final VoidCallback? onDelete;

  const FactorRow({
    super.key,
    required this.factor,
    this.value,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onDelete,
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    factor.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (factor.isCount && factor.unit != null)
                  Text(
                    '· ${factor.unit}',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textMuted),
                  )
                else if (!factor.isCount && value != null)
                  Text(
                    '$value',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                if (onDelete != null)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 32, minHeight: 32),
                    splashRadius: 20,
                    icon: const Icon(LucideIcons.trash2,
                        size: 18, color: AppColors.textMuted),
                    tooltip: 'Удалить фактор',
                    onPressed: onDelete,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (factor.isCount)
              _CountStepper(factor: factor, value: value ?? 0)
            else
              _RatingChips(factor: factor, value: value),
          ],
        ),
      ),
    );
  }
}

class _RatingChips extends StatelessWidget {
  final Factor factor;
  final int? value;
  const _RatingChips({required this.factor, this.value});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<FactorsCubit>();
    final scaleValues = [
      for (var v = factor.scaleMin; v <= factor.scaleMax; v++) v,
    ];
    final v = value;
    final selectedLabel =
        (v != null && factor.labels != null) ? factor.labels![v.toString()] : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < scaleValues.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _ValueChip(
                  value: scaleValues[i],
                  selected: value == scaleValues[i],
                  onTap: () => cubit.setValue(factor.id, scaleValues[i]),
                ),
              ),
            ],
          ],
        ),
        if (selectedLabel != null) ...[
          const SizedBox(height: 6),
          Text(
            selectedLabel,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }
}

class _ValueChip extends StatelessWidget {
  final int value;
  final bool selected;
  final VoidCallback onTap;
  const _ValueChip({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accent : AppColors.bg,
      borderRadius: BorderRadius.circular(AppRadii.inner),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.inner),
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Center(
            child: Text(
              '$value',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// −/value/+ stepper for COUNT factors. Big tap targets, min 0, no upper cap.
class _CountStepper extends StatelessWidget {
  final Factor factor;
  final int value;
  const _CountStepper({required this.factor, required this.value});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<FactorsCubit>();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(AppRadii.inner),
      ),
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          _StepButton(
            icon: LucideIcons.minus,
            filled: false,
            onTap: value > 0
                ? () => cubit.step(factor.id, -1)
                : null,
          ),
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$value',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (factor.unit != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      factor.unit!,
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ),
          _StepButton(
            icon: LucideIcons.plus,
            filled: true,
            onTap: () => cubit.step(factor.id, 1),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final bool filled;
  final VoidCallback? onTap;
  const _StepButton({
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: filled
          ? (enabled ? AppColors.accent : AppColors.textMuted)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(
            icon,
            size: 22,
            color: filled
                ? Colors.white
                : (enabled ? AppColors.textSecondary : AppColors.textMuted),
          ),
        ),
      ),
    );
  }
}
