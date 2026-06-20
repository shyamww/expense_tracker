import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../constants/category_picker_presets.dart';
import '../constants/categories.dart';
import '../models/expense_category.dart';
import '../providers/category_provider.dart';
import '../providers/expense_provider.dart';
import '../widgets/web_dashboard_shell.dart';

class CategoryManagementScreen extends StatelessWidget {
  const CategoryManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (WebDashboardShell.useFor(context)) {
      return WebDashboardShell(
        selectedRoute: AppRoutes.settings,
        title: 'Categories',
        subtitle: 'Manage the labels and icons used for expenses',
        actions: [
          FilledButton.icon(
            onPressed: () => _openEditor(context, null),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add category'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
        child: Consumer<CategoryProvider>(
          builder: (context, cat, _) => _buildWebBody(context, cat),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        centerTitle: true,
      ),
      body: Consumer<CategoryProvider>(
        builder: (context, cat, _) {
          final list = cat.categories;
          final archived = cat.archivedCategories;
          if (list.isEmpty && archived.isEmpty) {
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
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            children: [
              ...list.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _CategoryRow(
                      category: c,
                      onEdit: () => _openEditor(context, c),
                      onArchive: c.systemLocked
                          ? null
                          : () => _archiveCategory(context, c),
                    ),
                  )),
              if (archived.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Archived',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                ...archived.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _CategoryRow(
                        category: c,
                        archived: true,
                        onEdit: () => _openEditor(context, c),
                        onArchive: () => _restoreCategory(context, c),
                      ),
                    )),
              ],
            ],
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

  Widget _buildWebBody(BuildContext context, CategoryProvider cat) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final list = cat.categories;
    final archived = cat.archivedCategories;

    Widget emptyState() {
      return SizedBox(
        height: 360,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.category_outlined,
                size: 48,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                'No categories yet',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Add categories to organize spending in reports.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget section(String title, List<ExpenseCategory> categories,
        {bool archivedSection = false}) {
      if (categories.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ...categories.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CategoryRow(
                category: c,
                archived: archivedSection,
                onEdit: () => _openEditor(context, c),
                onArchive: archivedSection
                    ? () => _restoreCategory(context, c)
                    : c.systemLocked
                        ? null
                        : () => _archiveCategory(context, c),
              ),
            ),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: WebPanel(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: list.isEmpty && archived.isEmpty
            ? emptyState()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.category_rounded,
                          color: scheme.primary,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Category list',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${list.length} active, ${archived.length} archived',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  section('Active categories', list),
                  if (archived.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    section('Archived', archived, archivedSection: true),
                  ],
                ],
              ),
      ),
    );
  }

  static Future<void> _openEditor(
      BuildContext context, ExpenseCategory? existing) async {
    if (WebDashboardShell.useFor(context)) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 620,
              maxHeight: MediaQuery.sizeOf(ctx).height - 80,
            ),
            child: _CategoryEditorSheet(existing: existing),
          ),
        ),
      );
      return;
    }

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

  static Future<void> _archiveCategory(
      BuildContext context, ExpenseCategory c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Archive category?'),
        content: Text(
          'Archive "${c.name}" so it no longer appears while adding expenses? Existing transactions will keep it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await context.read<CategoryProvider>().archiveCategory(c);
    if (!context.mounted) return;
    await context.read<ExpenseProvider>().loadExpenses();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Archived "${c.name}"'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static Future<void> _restoreCategory(
      BuildContext context, ExpenseCategory c) async {
    await context.read<CategoryProvider>().restoreCategory(c);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Restored "${c.name}"'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final ExpenseCategory category;
  final bool archived;
  final VoidCallback onEdit;
  final VoidCallback? onArchive;

  const _CategoryRow({
    required this.category,
    required this.onEdit,
    required this.onArchive,
    this.archived = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final info = category.toCategoryInfo();
    return Material(
      color: scheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: info.color.withValues(alpha: 0.15),
          child: Icon(info.icon, color: info.color, size: 22),
        ),
        title: Text(
          category.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: archived ? scheme.onSurfaceVariant : scheme.onSurface,
          ),
        ),
        subtitle: category.systemLocked
            ? Text(
                'Used for money received (keep name)',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              )
            : archived
                ? Text(
                    'Archived',
                    style:
                        TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  )
                : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
              onPressed: onEdit,
            ),
            if (onArchive != null)
              IconButton(
                icon: Icon(
                  archived ? Icons.unarchive_outlined : Icons.archive_outlined,
                  color: archived ? scheme.primary : scheme.onSurfaceVariant,
                ),
                tooltip: archived ? 'Restore' : 'Archive',
                onPressed: onArchive,
              ),
          ],
        ),
      ),
    );
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
