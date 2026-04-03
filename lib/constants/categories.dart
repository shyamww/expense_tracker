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

const List<CategoryInfo> appCategories = [
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

CategoryInfo getCategoryInfo(String name) {
  return appCategories.firstWhere(
    (c) => c.name == name,
    orElse: () => const CategoryInfo(
      name: 'Other',
      icon: Icons.category,
      color: Color(0xFF78909C),
    ),
  );
}
