import '../constants/categories.dart';
import '../models/expense_category.dart';

/// Built-in rows for DB seed / migration (no BuildContext).
List<ExpenseCategory> buildSeededExpenseCategories() {
  var order = 0;
  return [
    for (final c in defaultCategoryInfos)
      ExpenseCategory(
        name: c.name,
        iconCodePoint: c.icon.codePoint,
        colorValue: encodeMaterialColor(c.color),
        sortOrder: order++,
        systemLocked: c.name == 'Received',
      ),
  ];
}
