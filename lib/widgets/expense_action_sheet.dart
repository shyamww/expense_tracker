import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/money.dart';
import '../core/transfer_note.dart';
import '../models/expense.dart';
import '../providers/category_provider.dart';
import '../providers/expense_provider.dart';
import '../screens/add_expense_screen.dart';

enum ExpenseActionSheetResult { modify, delete }

/// Long-press actions: modify or delete. [onClosed] runs when the sheet is dismissed.
Future<bool> showExpenseActionsBottomSheet({
  required BuildContext context,
  required Expense expense,

  /// When set, edit screen keeps this account (e.g. from account ledger).
  String? lockAccountTo,
  Future<void> Function()? onRefresh,
  VoidCallback? onClosed,
}) async {
  if (expense.id == null) return false;
  var changed = false;
  try {
    final action = await _showExpenseActionPicker(context, expense);

    if (!context.mounted) return changed;

    if (action == ExpenseActionSheetResult.modify) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddExpenseScreen(
            expenseToEdit: expense,
            lockAccountTo: lockAccountTo,
          ),
        ),
      );
      changed = true;
    } else if (action == ExpenseActionSheetResult.delete) {
      final messenger = ScaffoldMessenger.of(context);
      final isXfer = CategoryProvider.isTransferCategory(expense.category);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dCtx) => AlertDialog(
          title: const Text('Delete entry?'),
          content: Text(
            isXfer
                ? 'Both sides of this transfer will be removed. This cannot be undone.'
                : 'This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dCtx, true),
              style:
                  FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed == true && context.mounted) {
        final deleted = await context
            .read<ExpenseProvider>()
            .deleteExpenseWithUndoData(expense.id!);
        final refresh = onRefresh;
        if (refresh != null && context.mounted) {
          await refresh();
        }
        if (deleted.isNotEmpty && context.mounted) {
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                deleted.length > 1 ? 'Transfer deleted' : 'Transaction deleted',
              ),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () async {
                  await context
                      .read<ExpenseProvider>()
                      .restoreDeletedExpenses(deleted);
                  final refresh = onRefresh;
                  if (refresh != null && context.mounted) {
                    await refresh();
                  }
                },
              ),
            ),
          );
        }
        changed = true;
      }
    }
  } finally {
    onClosed?.call();
  }
  return changed;
}

Future<ExpenseActionSheetResult?> _showExpenseActionPicker(
  BuildContext context,
  Expense expense,
) {
  if (_useWebActionDialog(context)) {
    return showDialog<ExpenseActionSheetResult>(
      context: context,
      builder: (dialogCtx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: _ExpenseActionContent(
            expense: expense,
            onSelected: (action) => Navigator.pop(dialogCtx, action),
            onClose: () => Navigator.pop(dialogCtx),
          ),
        ),
      ),
    );
  }

  return showModalBottomSheet<ExpenseActionSheetResult>(
    context: context,
    showDragHandle: true,
    builder: (sheetCtx) {
      return SafeArea(
        child: _ExpenseActionContent(
          expense: expense,
          onSelected: (action) => Navigator.pop(sheetCtx, action),
        ),
      );
    },
  );
}

bool _useWebActionDialog(BuildContext context) {
  return kIsWeb && MediaQuery.sizeOf(context).width >= 560;
}

class _ExpenseActionContent extends StatelessWidget {
  const _ExpenseActionContent({
    required this.expense,
    required this.onSelected,
    this.onClose,
  });

  final Expense expense;
  final ValueChanged<ExpenseActionSheetResult> onSelected;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isWebDialog = _useWebActionDialog(context);
    final canModify = !CategoryProvider.isTransferCategory(expense.category);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, isWebDialog ? 18 : 8, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (expense.note.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        displayExpenseNote(expense.note),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      '₹ ${formatRupeesFixed2FromPaisa(expense.amount)}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (onClose != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Close',
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          if (canModify)
            _ActionDialogRow(
              icon: Icons.edit_outlined,
              label: 'Modify',
              color: scheme.primary,
              onTap: () => onSelected(ExpenseActionSheetResult.modify),
            ),
          _ActionDialogRow(
            icon: Icons.delete_outline,
            label: 'Delete',
            color: const Color(0xFFDC2626),
            onTap: () => onSelected(ExpenseActionSheetResult.delete),
          ),
        ],
      ),
    );
  }
}

class _ActionDialogRow extends StatelessWidget {
  const _ActionDialogRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: color, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
