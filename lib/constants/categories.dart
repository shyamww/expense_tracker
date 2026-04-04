import 'package:flutter/material.dart';

class CategoryInfo {
  final String name;
  final IconData icon;
  final Color color;

  const CategoryInfo({
    required this.name,
    required this.icon,
    required this.color,
  });
}

/// ARGB int for persistence (SQLite / JSON).
int encodeMaterialColor(Color c) {
  final a = (c.a * 255).round() & 0xFF;
  final r = (c.r * 255).round() & 0xFF;
  final g = (c.g * 255).round() & 0xFF;
  final b = (c.b * 255).round() & 0xFF;
  return (a << 24) | (r << 16) | (g << 8) | b;
}

/// Shipped defaults; also used to seed the database on first install / migration.
const List<CategoryInfo> defaultCategoryInfos = [
  CategoryInfo(
    name: 'Food',
    icon: Icons.restaurant,
    color: Color(0xFFEF5350),
  ),
  CategoryInfo(
    name: 'Clothes',
    icon: Icons.checkroom,
    color: Color(0xFFAB47BC),
  ),
  CategoryInfo(
    name: 'Travel',
    icon: Icons.directions_car,
    color: Color(0xFF42A5F5),
  ),
  CategoryInfo(
    name: 'Lending',
    icon: Icons.arrow_upward,
    color: Color(0xFFFFA726),
  ),
  CategoryInfo(
    name: 'Investment',
    icon: Icons.trending_up,
    color: Color(0xFF66BB6A),
  ),
  CategoryInfo(
    name: 'Received',
    icon: Icons.arrow_downward,
    color: Color(0xFF26C6DA),
  ),
];

/// Fallback styling for expense strings that are not in the user’s category list.
CategoryInfo unknownCategoryInfo(String name) => CategoryInfo(
      name: name,
      icon: Icons.label_outline_rounded,
      color: const Color(0xFF78909C),
    );

@Deprecated('Use CategoryProvider / defaultCategoryInfos')
List<CategoryInfo> get appCategories => defaultCategoryInfos;

CategoryInfo getCategoryInfo(String name) {
  for (final c in defaultCategoryInfos) {
    if (c.name == name) return c;
  }
  return unknownCategoryInfo(name);
}
