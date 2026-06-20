import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/money.dart';
import '../models/income_entry.dart';
import '../providers/income_provider.dart';

enum IncomeActionSheetResult { modify, delete }

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
    final action = await _showIncomeActionPicker(context, entry);
    if (!context.mounted) return;

    if (action == IncomeActionSheetResult.modify) {
      await onModify(entry);
    } else if (action == IncomeActionSheetResult.delete) {
      final messenger = ScaffoldMessenger.of(context);
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
              style:
                  FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed == true && context.mounted) {
        final deleted = await context
            .read<IncomeProvider>()
            .deleteIncomeHistoryWithUndoData(entry.id!);
        final refresh = onRefresh;
        if (refresh != null) await refresh();
        if (deleted != null && context.mounted) {
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(
              content: const Text('Income entry deleted'),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () async {
                  await context
                      .read<IncomeProvider>()
                      .restoreDeletedIncomeHistoryEntry(deleted);
                  final refresh = onRefresh;
                  if (refresh != null && context.mounted) {
                    await refresh();
                  }
                },
              ),
            ),
          );
        }
      }
    }
  } finally {
    onClosed?.call();
  }
}

Future<IncomeActionSheetResult?> _showIncomeActionPicker(
  BuildContext context,
  IncomeEntry entry,
) {
  if (_useWebActionDialog(context)) {
    return showDialog<IncomeActionSheetResult>(
      context: context,
      builder: (dialogCtx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: _IncomeActionContent(
            entry: entry,
            onSelected: (action) => Navigator.pop(dialogCtx, action),
            onClose: () => Navigator.pop(dialogCtx),
          ),
        ),
      ),
    );
  }

  return showModalBottomSheet<IncomeActionSheetResult>(
    context: context,
    showDragHandle: true,
    builder: (sheetCtx) {
      return SafeArea(
        child: _IncomeActionContent(
          entry: entry,
          onSelected: (action) => Navigator.pop(sheetCtx, action),
        ),
      );
    },
  );
}

bool _useWebActionDialog(BuildContext context) {
  return kIsWeb && MediaQuery.sizeOf(context).width >= 560;
}

class _IncomeActionContent extends StatelessWidget {
  const _IncomeActionContent({
    required this.entry,
    required this.onSelected,
    this.onClose,
  });

  final IncomeEntry entry;
  final ValueChanged<IncomeActionSheetResult> onSelected;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isWebDialog = _useWebActionDialog(context);
    final title = entry.note.isNotEmpty ? entry.note : 'Income';

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
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '+ ₹ ${formatRupeesFixed2FromPaisa(entry.amount)}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: const Color(0xFF059669),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (entry.account.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        entry.account,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
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
          _ActionDialogRow(
            icon: Icons.edit_outlined,
            label: 'Modify',
            color: scheme.primary,
            onTap: () => onSelected(IncomeActionSheetResult.modify),
          ),
          _ActionDialogRow(
            icon: Icons.delete_outline,
            label: 'Delete',
            color: const Color(0xFFDC2626),
            onTap: () => onSelected(IncomeActionSheetResult.delete),
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
