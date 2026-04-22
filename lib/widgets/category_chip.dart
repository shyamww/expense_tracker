import 'package:flutter/material.dart';
import '../constants/categories.dart';

class CategoryChip extends StatelessWidget {
  final CategoryInfo category;
  final bool selected;
  final VoidCallback onTap;

  const CategoryChip({
    super.key,
    required this.category,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? category.color.withValues(alpha: 0.15)
              : scheme.surface,
          borderRadius: BorderRadius.circular(12),
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
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              category.name,
              style: TextStyle(
                fontSize: 12,
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
