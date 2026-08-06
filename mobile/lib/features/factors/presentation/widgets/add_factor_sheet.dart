import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme.dart';
import '../../cubit/factors_cubit.dart';
import '../../data/factors_models.dart';

/// Bottom sheet to create a custom factor.
///
/// Fields: название, тип (Оценка 0–5 = rating / Счётчик = count), категория
/// (defaults to [defaultCategoryId]). For rating an optional scale (min/max,
/// default 0..5); for count an optional unit ("порций", "чашек", …).
///
/// Show it with a `BlocProvider.value` wrapper so it can reach [FactorsCubit].
class AddFactorSheet extends StatefulWidget {
  final String? defaultCategoryId;
  const AddFactorSheet({super.key, this.defaultCategoryId});

  @override
  State<AddFactorSheet> createState() => _AddFactorSheetState();
}

class _AddFactorSheetState extends State<AddFactorSheet> {
  final _nameController = TextEditingController();
  final _unitController = TextEditingController();
  final _minController = TextEditingController(text: '0');
  final _maxController = TextEditingController(text: '5');

  String _kind = 'rating';
  String? _categoryId;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.defaultCategoryId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _nameController.text.trim().isNotEmpty && _categoryId != null;

  Future<void> _submit(BuildContext context) async {
    final cubit = context.read<FactorsCubit>();
    final name = _nameController.text.trim();
    final categoryId = _categoryId;
    if (name.isEmpty || categoryId == null) return;

    int? scaleMin;
    int? scaleMax;
    String? unit;
    if (_kind == 'rating') {
      scaleMin = int.tryParse(_minController.text.trim()) ?? 0;
      scaleMax = int.tryParse(_maxController.text.trim()) ?? 5;
      if (scaleMax <= scaleMin) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
              content: Text('Максимум шкалы должен быть больше минимума')));
        return;
      }
    } else {
      unit = _unitController.text.trim();
    }

    await cubit.createFactor(
      categoryId: categoryId,
      name: name,
      kind: _kind,
      scaleMin: scaleMin,
      scaleMax: scaleMax,
      unit: unit,
    );
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _createCategory(BuildContext context) async {
    final cubit = context.read<FactorsCubit>();
    final result = await showDialog<_NewCategoryResult>(
      context: context,
      builder: (_) => const _NewCategoryDialog(),
    );
    if (result == null) return;
    final id = await cubit.createCategory(name: result.name, emoji: result.emoji);
    if (id != null) setState(() => _categoryId = id);
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.select<FactorsCubit, List<FactorCategory>>(
      (c) => c.state.categories,
    );
    final mutating = context.select<FactorsCubit, bool>((c) => c.state.mutating);

    // Keep the selected category valid against the current list.
    if (_categoryId != null && !categories.any((c) => c.id == _categoryId)) {
      _categoryId = categories.isNotEmpty ? categories.first.id : null;
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
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
            const Text(
              'Новый фактор',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _label('Название'),
            TextField(
              controller: _nameController,
              onChanged: (_) => setState(() {}),
              textCapitalization: TextCapitalization.sentences,
              decoration: _inputDecoration('Например: Настроение'),
            ),
            const SizedBox(height: 16),
            _label('Тип'),
            _KindSelector(
              kind: _kind,
              onChanged: (k) => setState(() => _kind = k),
            ),
            const SizedBox(height: 16),
            if (_kind == 'rating') ...[
              _label('Шкала'),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration('мин'),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('–',
                        style: TextStyle(color: AppColors.textMuted)),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _maxController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration('макс'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              _label('Единица (необязательно)'),
              TextField(
                controller: _unitController,
                decoration: _inputDecoration('порций, чашек, …'),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _label('Категория')),
                TextButton.icon(
                  onPressed:
                      mutating ? null : () => _createCategory(context),
                  icon: const Icon(LucideIcons.plus, size: 16),
                  label: const Text('Новая'),
                ),
              ],
            ),
            _CategoryDropdown(
              categories: categories,
              value: _categoryId,
              onChanged: (id) => setState(() => _categoryId = id),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: (!_canSubmit || mutating) ? null : () => _submit(context),
              icon: mutating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(LucideIcons.check, size: 20),
              label: const Text('Добавить фактор'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: AppColors.bg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.inner),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.inner),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.inner),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
      );
}

class _KindSelector extends StatelessWidget {
  final String kind;
  final ValueChanged<String> onChanged;
  const _KindSelector({required this.kind, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _KindChip(
            label: 'Оценка 0–5',
            icon: LucideIcons.star,
            selected: kind == 'rating',
            onTap: () => onChanged('rating'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _KindChip(
            label: 'Счётчик',
            icon: LucideIcons.hash,
            selected: kind == 'count',
            onTap: () => onChanged('count'),
          ),
        ),
      ],
    );
  }
}

class _KindChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _KindChip({
    required this.label,
    required this.icon,
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
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: selected ? Colors.white : AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  final List<FactorCategory> categories;
  final String? value;
  final ValueChanged<String?> onChanged;
  const _CategoryDropdown({
    required this.categories,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const Text(
        'Нет категорий — создайте новую.',
        style: TextStyle(fontSize: 13, color: AppColors.textMuted),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(AppRadii.inner),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          icon: const Icon(LucideIcons.chevronDown, size: 18),
          items: [
            for (final c in categories)
              DropdownMenuItem(
                value: c.id,
                child: Text('${c.emoji ?? '•'}  ${c.name}'),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _NewCategoryResult {
  final String name;
  final String? emoji;
  const _NewCategoryResult(this.name, this.emoji);
}

class _NewCategoryDialog extends StatefulWidget {
  const _NewCategoryDialog();

  @override
  State<_NewCategoryDialog> createState() => _NewCategoryDialogState();
}

class _NewCategoryDialogState extends State<_NewCategoryDialog> {
  final _nameController = TextEditingController();
  final _emojiController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emojiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Новая категория'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Название'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emojiController,
            decoration: const InputDecoration(labelText: 'Эмодзи (необязательно)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) return;
            final emoji = _emojiController.text.trim();
            Navigator.of(context).pop(
              _NewCategoryResult(name, emoji.isEmpty ? null : emoji),
            );
          },
          child: const Text('Создать'),
        ),
      ],
    );
  }
}
