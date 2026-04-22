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
  VoidCallback? onClosed,
}) async {
  if (expense.id == null) return false;
  var changed = false;
  try {
    final action = await showModalBottomSheet<ExpenseActionSheetResult>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Text(
                  expense.category,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              if (expense.note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                  child: Text(
                    displayExpenseNote(expense.note),
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  '₹${formatRupeesFixed2FromPaisa(expense.amount)}',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800),
                ),
              ),
              if (!CategoryProvider.isTransferCategory(expense.category))
                ListTile(
                  leading: Icon(Icons.edit_outlined,
                      color: Colors.deepPurple.shade600),
                  title: const Text('Modify'),
                  onTap: () {
                    Navigator.pop(sheetCtx, ExpenseActionSheetResult.modify);
                  },
                ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red.shade600),
                title: Text('Delete',
                    style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(sheetCtx, ExpenseActionSheetResult.delete);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

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
        await context.read<ExpenseProvider>().deleteExpense(expense.id!);
        changed = true;
      }
    }
  } finally {
    onClosed?.call();
  }
  return changed;
}
