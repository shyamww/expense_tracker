import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../constants/categories.dart';

class ExpenseTile extends StatelessWidget {
  final Expense expense;
  final bool isSelected;
  final VoidCallback? onLongPress;
  final VoidCallback? onDeselect;

  const ExpenseTile({
    super.key,
    required this.expense,
    this.isSelected = false,
    this.onLongPress,
    this.onDeselect,
  });

  @override
  Widget build(BuildContext context) {
    final info = getCategoryInfo(expense.category);
    final created = DateTime.tryParse(expense.createdAt);
    final dayOnly = DateTime.tryParse(expense.date);
    final dateStr = created != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(created)
        : (dayOnly != null
            ? DateFormat('dd MMM yyyy').format(dayOnly)
            : expense.date);
    final scheme = Theme.of(context).colorScheme;

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
                    color: info.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(info.icon, color: info.color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.category,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      if (expense.note.isNotEmpty)
                        Text(
                          expense.note,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
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
                  '₹ ${expense.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: scheme.onSurface,
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
