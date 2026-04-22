import 'package:flutter/material.dart';

/// Selectable chip for an account (bank / cash), similar density to [CategoryChip].
class AccountChip extends StatelessWidget {
  final String name;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  const AccountChip({
    super.key,
    required this.name,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final horizontal = compact ? 10.0 : 14.0;
    final vertical = compact ? 8.0 : 10.0;
    final iconSize = compact ? 18.0 : 22.0;
    final labelSize = compact ? 12.0 : 13.0;
    final radius = compact ? 10.0 : 12.0;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.12)
              : scheme.surface,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: selected ? scheme.primary : theme.dividerColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_balance_rounded,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
              size: iconSize,
            ),
            SizedBox(width: compact ? 6 : 8),
            Text(
              name,
              style: TextStyle(
                fontSize: labelSize,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? scheme.primary : scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
