import 'package:flutter/material.dart';
import '../constants/categories.dart';
import '../constants/category_picker_presets.dart';

/// Icon for categories created from unknown expense strings (DB / import).
const int kUnknownCategoryIconCodePoint = 0xe892; // label_outline

class ExpenseCategory {
  final int? id;
  final String name;
  final int iconCodePoint;
  final int colorValue;
  final int sortOrder;
  final bool systemLocked;
  final bool archived;

  const ExpenseCategory({
    this.id,
    required this.name,
    required this.iconCodePoint,
    required this.colorValue,
    this.sortOrder = 0,
    this.systemLocked = false,
    this.archived = false,
  });

  IconData get iconData {
    for (final ic in kAllKnownCategoryIcons) {
      if (ic.codePoint == iconCodePoint) return ic;
    }
    return Icons.label_outline_rounded;
  }

  CategoryInfo toCategoryInfo() => CategoryInfo(
        name: name,
        icon: iconData,
        color: Color(colorValue),
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'icon_code_point': iconCodePoint,
        'color': colorValue,
        'sort_order': sortOrder,
        'system_locked': systemLocked ? 1 : 0,
        'archived': archived ? 1 : 0,
      };

  factory ExpenseCategory.fromMap(Map<String, dynamic> map) {
    return ExpenseCategory(
      id: map['id'] as int?,
      name: map['name'] as String,
      iconCodePoint: map['icon_code_point'] as int,
      colorValue: map['color'] as int,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      systemLocked: (map['system_locked'] as num?)?.toInt() == 1,
      archived: (map['archived'] as num?)?.toInt() == 1,
    );
  }

  ExpenseCategory copyWith({
    int? id,
    String? name,
    int? iconCodePoint,
    int? colorValue,
    int? sortOrder,
    bool? systemLocked,
    bool? archived,
  }) {
    return ExpenseCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      sortOrder: sortOrder ?? this.sortOrder,
      systemLocked: systemLocked ?? this.systemLocked,
      archived: archived ?? this.archived,
    );
  }
}
