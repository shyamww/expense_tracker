import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/category_picker_presets.dart';
import '../constants/categories.dart';
import '../models/expense_category.dart';
import '../providers/category_provider.dart';
import '../providers/expense_provider.dart';

class CategoryManagementScreen extends StatelessWidget {
  const CategoryManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        centerTitle: true,
      ),
      body: Consumer<CategoryProvider>(
        builder: (context, cat, _) {
          final list = cat.categories;
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.category_outlined,
                        size: 56, color: scheme.onSurfaceVariant),
                    const SizedBox(height: 16),
                    Text(
                      'No categories yet',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap Add to create one.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final c = list[i];
              final info = c.toCategoryInfo();
              return Material(
                color: scheme.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.dividerColor),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: info.color.withValues(alpha: 0.15),
                    child: Icon(info.icon, color: info.color, size: 22),
                  ),
                  title: Text(c.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: c.systemLocked
                      ? Text(
                          'Used for money received (keep name)',
                          style: TextStyle(
                              fontSize: 12, color: scheme.onSurfaceVariant),
                        )
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Edit',
                        onPressed: () => _openEditor(context, c),
                      ),
                      if (!c.systemLocked)
                        IconButton(
                          icon: Icon(Icons.delete_outline,
                              color: Colors.red.shade400),
                          tooltip: 'Delete',
                          onPressed: () => _confirmDelete(context, c),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
      ),
    );
  }

  static Future<void> _openEditor(
      BuildContext context, ExpenseCategory? existing) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _CategoryEditorSheet(existing: existing),
    );
  }

  static Future<void> _confirmDelete(
      BuildContext context, ExpenseCategory c) async {
    final cat = context.read<CategoryProvider>();
    final count = await cat.expenseCountFor(c.name);
    if (!context.mounted) return;

    String? reassignTo;
    if (count > 0) {
      final others = cat.categories.where((x) => x.id != c.id).toList();
      if (others.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Cannot delete: $count expense(s) and no other category to move them to.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      var targetCategory = others.first.name;
      final picked = await showDialog<String>(
        context: context,
        builder: (dCtx) => StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Move expenses first'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count expense(s) use "${c.name}". Choose a category to move them to:',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: targetCategory,
                    decoration: const InputDecoration(labelText: 'Move to'),
                    items: others
                        .map(
                          (o) => DropdownMenuItem(
                              value: o.name, child: Text(o.name)),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setLocal(() => targetCategory = v);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dCtx),
                    child: const Text('Cancel')),
                FilledButton(
                  onPressed: () => Navigator.pop(dCtx, targetCategory),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ),
      );
      if (picked == null || picked.isEmpty) return;
      reassignTo = picked;
    } else {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dCtx) => AlertDialog(
          title: const Text('Delete category?'),
          content: Text('Remove "${c.name}"? This cannot be undone.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dCtx, false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(dCtx, true),
              style:
                  FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    if (!context.mounted) return;
    final provider = context.read<CategoryProvider>();
    final expenseProvider = context.read<ExpenseProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await provider.deleteCategory(c, reassignTo: reassignTo);
      if (!context.mounted) return;
      await expenseProvider.loadExpenses();
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Deleted "${c.name}"'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on StateError catch (e) {
      if (!context.mounted) return;
      final s = e.toString();
      final msg = s.contains('reassign_required')
          ? 'Pick a category to move expenses to.'
          : s.contains('locked_delete')
              ? 'This category cannot be deleted.'
              : 'Could not delete category.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );
    }
  }
}

class _CategoryEditorSheet extends StatefulWidget {
  final ExpenseCategory? existing;

  const _CategoryEditorSheet({this.existing});

  @override
  State<_CategoryEditorSheet> createState() => _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends State<_CategoryEditorSheet> {
  late final TextEditingController _name;
  late int _iconCodePoint;
  late int _colorValue;

  bool get _isEdit => widget.existing != null;
  bool get _nameLocked => widget.existing?.systemLocked == true;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _iconCodePoint = e?.iconCodePoint ?? kCategoryPickerIcons.first.codePoint;
    _colorValue =
        e?.colorValue ?? encodeMaterialColor(kCategoryPickerColors.first);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a name')),
      );
      return;
    }

    final provider = context.read<CategoryProvider>();
    final expenseProvider = context.read<ExpenseProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final draft = ExpenseCategory(
      id: widget.existing?.id,
      name: name,
      iconCodePoint: _iconCodePoint,
      colorValue: _colorValue,
      sortOrder: widget.existing?.sortOrder ?? 0,
      systemLocked: widget.existing?.systemLocked ?? false,
    );

    try {
      if (_isEdit) {
        await provider.updateCategory(draft,
            previousName: widget.existing!.name);
      } else {
        await provider.addCategory(draft);
      }
      if (!mounted) return;
      await expenseProvider.loadExpenses();
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(_isEdit ? 'Category updated' : 'Category added'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on StateError catch (e) {
      if (!mounted) return;
      final s = e.toString();
      final msg = s.contains('duplicate_name')
          ? 'A category with this name already exists.'
          : s.contains('locked_rename')
              ? 'This name is fixed for system categories.'
              : 'Could not save.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding:
          EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isEdit ? 'Edit category' : 'New category',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              enabled: !_nameLocked,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Subscriptions',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (_nameLocked) ...[
              const SizedBox(height: 6),
              Text(
                'Name is locked so income logic keeps working.',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 18),
            Text(
              'Icon',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kCategoryPickerIcons.map((ic) {
                final selected = ic.codePoint == _iconCodePoint;
                return InkWell(
                  onTap: () => setState(() => _iconCodePoint = ic.codePoint),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: selected
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.12)
                          : scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : theme.dividerColor,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Icon(
                      ic,
                      size: 22,
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            Text(
              'Color',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: kCategoryPickerColors.map((col) {
                final v = encodeMaterialColor(col);
                final selected = v == _colorValue;
                return GestureDetector(
                  onTap: () => setState(() => _colorValue = v),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: col,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? scheme.onSurface : theme.dividerColor,
                        width: selected ? 3 : 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(_isEdit ? 'Save changes' : 'Add category'),
            ),
          ],
        ),
      ),
    );
  }
}
