import 'package:flutter/material.dart';
import '../constants/categories.dart';

class CategoryChip extends StatelessWidget {
  final CategoryInfo category;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  const CategoryChip({
    super.key,
    required this.category,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final horizontal = compact ? 10.0 : 14.0;
    final vertical = compact ? 7.0 : 10.0;
    final iconSize = compact ? 20.0 : 26.0;
    final labelSize = compact ? 11.0 : 12.0;
    final radius = compact ? 10.0 : 12.0;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
        decoration: BoxDecoration(
          color: selected
              ? category.color.withValues(alpha: 0.15)
              : scheme.surface,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: selected ? category.color : theme.dividerColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              category.icon,
              color: selected ? category.color : scheme.onSurfaceVariant,
              size: iconSize,
            ),
            SizedBox(height: compact ? 2 : 4),
            Text(
              category.name,
              style: TextStyle(
                fontSize: labelSize,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? category.color : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
