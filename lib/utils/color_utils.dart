import 'package:flutter/material.dart';

class ColorUtils {
  static const List<Color> avatarColors = [
    Color(0xFFFF5252), // Red
    Color(0xFFFF4081), // Pink
    Color(0xFFE040FB), // Purple
    Color(0xFF7C4DFF), // Deep Purple
    Color(0xFFFF6E40), // Deep Orange
    Color(0xFFFFAB40), // Amber
    Color(0xFFEC407A), // Rose
    Color(0xFFAB47BC), // Medium Purple
    Color(0xFFEF5350), // Light Red
    Color(0xFFFFA726), // Orange
    Color(0xFFFF7043), // Deep Coral
    Color(0xFFBA68C8), // Light Purple
  ];

  /// Returns a consistent color for a given key (user ID, username, or email).
  static Color getColorForUser(String key) {
    if (key.isEmpty) return avatarColors[0];
    int hash = 0;
    for (int i = 0; i < key.length; i++) {
        hash = key.codeUnitAt(i) + ((hash << 5) - hash);
    }
    final index = hash.abs() % avatarColors.length;
    return avatarColors[index];
  }
}
