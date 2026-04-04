import 'package:flutter/material.dart';
import '../models/income_entry.dart';
import '../db/database_helper.dart';

/// Same pattern as expense actions: Modify + Delete after long press selection.
Future<void> showIncomeHistoryActionsSheet({
  required BuildContext context,
  required IncomeEntry entry,
  required Future<void> Function(IncomeEntry entry) onModify,
  Future<void> Function()? onRefresh,
  VoidCallback? onClosed,
}) async {
  if (entry.id == null) return;
  try {
    await showModalBottomSheet<void>(
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
                  entry.note.isNotEmpty ? entry.note : 'Income',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  '+ ₹${entry.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade800,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.edit_outlined, color: Colors.deepPurple.shade600),
                title: const Text('Modify'),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  await onModify(entry);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red.shade600),
                title: Text('Delete', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600)),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      title: const Text('Delete income entry?'),
                      content: const Text('This cannot be undone.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dCtx, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dCtx, true),
                          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && context.mounted) {
                    await DatabaseHelper().deleteIncomeHistoryEntry(entry.id!);
                    final refresh = onRefresh;
                    if (refresh != null) await refresh();
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  } finally {
    onClosed?.call();
  }
}
