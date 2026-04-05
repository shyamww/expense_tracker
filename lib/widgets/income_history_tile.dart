import 'package:flutter/material.dart';
import '../core/money.dart';
import '../models/income_entry.dart';

/// Matches [ExpenseTile] interaction: Material + InkWell, selection ring, long press for actions.
class IncomeHistoryTile extends StatelessWidget {
  final IncomeEntry entry;
  final String dateStr;
  final bool isSelected;
  final VoidCallback? onLongPress;
  final VoidCallback? onDeselect;

  const IncomeHistoryTile({
    super.key,
    required this.entry,
    required this.dateStr,
    this.isSelected = false,
    this.onLongPress,
    this.onDeselect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final green = Colors.green.shade600;
    final greenBg = Colors.green.shade50;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected ? scheme.primary.withOpacity(0.08) : scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected ? scheme.primary : Theme.of(context).dividerColor.withOpacity(0.25),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: isSelected ? onDeselect : null,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: greenBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.south_west_rounded, color: green, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.note.isNotEmpty ? entry.note : 'Income',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      if (entry.account.isNotEmpty)
                        Text(
                          entry.account,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      Text(
                        dateStr,
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '+ ₹ ${formatRupeesFixed2FromPaisa(entry.amount)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
