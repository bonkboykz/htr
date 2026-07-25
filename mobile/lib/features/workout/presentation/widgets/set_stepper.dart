import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

/// A labelled -/value/+ control with big tap targets.
/// Tapping the value (when [onTapValue] is set) lets the user type a number.
class SetStepper extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final VoidCallback? onTapValue;
  final Color accent;

  const SetStepper({
    super.key,
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
    this.onTapValue,
    this.accent = AppColors.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadii.inner),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SquareButton(
                icon: Icons.remove,
                onTap: onMinus,
                filled: false,
                accent: accent,
              ),
              Expanded(
                child: InkWell(
                  onTap: onTapValue,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          decoration: onTapValue != null
                              ? TextDecoration.underline
                              : null,
                          decorationColor: AppColors.border,
                          decorationStyle: TextDecorationStyle.dotted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _SquareButton(
                icon: Icons.add,
                onTap: onPlus,
                filled: true,
                accent: accent,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SquareButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;
  final Color accent;

  const _SquareButton({
    required this.icon,
    required this.onTap,
    required this.filled,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
        color: filled ? accent : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              icon,
              size: 20,
              color: filled ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
