import 'package:flutter/material.dart';

/// Quick-pick icons for the category editor.
const List<IconData> kCategoryPickerIcons = [
  Icons.restaurant_rounded,
  Icons.checkroom_rounded,
  Icons.directions_car_rounded,
  Icons.home_rounded,
  Icons.movie_rounded,
  Icons.local_hospital_rounded,
  Icons.school_rounded,
  Icons.pets_rounded,
  Icons.sports_soccer_rounded,
  Icons.local_grocery_store_rounded,
  Icons.phone_android_rounded,
  Icons.wifi_rounded,
  Icons.card_giftcard_rounded,
  Icons.work_rounded,
  Icons.flight_rounded,
  Icons.fitness_center_rounded,
  Icons.label_outline_rounded,
];

/// Every [IconData] that may be stored as `icon_code_point` in the DB (picker +
/// seeded defaults that use non-`..._rounded` variants). Used so release builds
/// can tree-shake the icon font without non-constant [IconData] construction.
const List<IconData> kAllKnownCategoryIcons = <IconData>[
  ...kCategoryPickerIcons,
  Icons.restaurant,
  Icons.checkroom,
  Icons.directions_car,
  Icons.arrow_upward,
  Icons.trending_up,
  Icons.arrow_downward,
  Icons.swap_horiz_rounded,
  Icons.call_received_rounded,
];

const List<Color> kCategoryPickerColors = [
  Color(0xFFEF5350),
  Color(0xFFAB47BC),
  Color(0xFF42A5F5),
  Color(0xFFFFA726),
  Color(0xFF66BB6A),
  Color(0xFF26C6DA),
  Color(0xFFEC407A),
  Color(0xFF8D6E63),
  Color(0xFF5C6BC0),
  Color(0xFF78909C),
  Color(0xFFFFCA28),
  Color(0xFF00ACC1),
];
