import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../app/theme.dart';
import '../../data/nutrition_models.dart';

/// The four system meals, in display order, with Russian labels.
const List<({String id, String label})> kMealOptions = [
  (id: 'meal-breakfast', label: 'Завтрак'),
  (id: 'meal-lunch', label: 'Обед'),
  (id: 'meal-dinner', label: 'Ужин'),
  (id: 'meal-snack', label: 'Перекус'),
];

/// Bottom sheet to quick-log a food. Returns a [QuickLogInput] via
/// `Navigator.pop` on submit, or null when dismissed.
Future<QuickLogInput?> showQuickLogSheet(
  BuildContext context, {
  String initialMealId = 'meal-breakfast',
}) {
  return showModalBottomSheet<QuickLogInput>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.card)),
    ),
    builder: (_) => _QuickLogSheet(initialMealId: initialMealId),
  );
}

class _QuickLogSheet extends StatefulWidget {
  final String initialMealId;
  const _QuickLogSheet({required this.initialMealId});

  @override
  State<_QuickLogSheet> createState() => _QuickLogSheetState();
}

class _QuickLogSheetState extends State<_QuickLogSheet> {
  final _name = TextEditingController();
  final _calories = TextEditingController();
  final _protein = TextEditingController();
  final _fat = TextEditingController();
  final _carbs = TextEditingController();

  late String _mealId = widget.initialMealId;
  bool _submitted = false;

  @override
  void dispose() {
    _name.dispose();
    _calories.dispose();
    _protein.dispose();
    _fat.dispose();
    _carbs.dispose();
    super.dispose();
  }

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      (int.tryParse(_calories.text.trim()) ?? -1) >= 0;

  void _submit() {
    setState(() => _submitted = true);
    if (!_valid) return;
    int? parse(TextEditingController c) {
      final t = c.text.trim();
      if (t.isEmpty) return null;
      return int.tryParse(t);
    }

    Navigator.of(context).pop(
      QuickLogInput(
        mealId: _mealId,
        name: _name.text.trim(),
        calories: int.parse(_calories.text.trim()),
        proteinG: parse(_protein),
        fatG: parse(_fat),
        carbsG: parse(_carbs),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Добавить продукт',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),

            // Meal selector
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in kMealOptions)
                  ChoiceChip(
                    label: Text(m.label),
                    selected: _mealId == m.id,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _mealId = m.id),
                    labelStyle: TextStyle(
                      color: _mealId == m.id
                          ? AppColors.accent
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: AppColors.bg,
                    selectedColor: AppColors.accentSoft,
                    side: BorderSide(
                      color: _mealId == m.id
                          ? AppColors.accent
                          : AppColors.border,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            _Field(
              controller: _name,
              label: 'Название',
              hint: 'напр. Овсянка на воде',
              error: _submitted && _name.text.trim().isEmpty
                  ? 'Введите название'
                  : null,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            _Field(
              controller: _calories,
              label: 'Калории, ккал',
              hint: '0',
              number: true,
              error: _submitted &&
                      (int.tryParse(_calories.text.trim()) ?? -1) < 0
                  ? 'Укажите калории'
                  : null,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Field(
                    controller: _protein,
                    label: 'Белки, г',
                    hint: '0',
                    number: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Field(
                    controller: _fat,
                    label: 'Жиры, г',
                    hint: '0',
                    number: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Field(
                    controller: _carbs,
                    label: 'Углеводы, г',
                    hint: '0',
                    number: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submit,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.plus, size: 18),
                  SizedBox(width: 8),
                  Text('Добавить'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool number;
  final bool autofocus;
  final String? error;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.number = false,
    this.autofocus = false,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          autofocus: autofocus,
          keyboardType: number
              ? const TextInputType.numberWithOptions(decimal: false)
              : TextInputType.text,
          inputFormatters:
              number ? [FilteringTextInputFormatter.digitsOnly] : null,
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            filled: true,
            fillColor: AppColors.bg,
            errorText: error,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.inner),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.inner),
              borderSide: const BorderSide(color: AppColors.accent),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.inner),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
      ],
    );
  }
}
