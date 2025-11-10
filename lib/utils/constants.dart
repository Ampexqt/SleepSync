import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF1A1D2B); // Dark blue/indigo background
  static const navBar = Color(0xFF1A1D2B); // Same as background for nav bar
  static const card = Color(0xFF2A2E3F); // Slightly lighter dark blue for cards
  static const primary = Color(0xFF4DD0E1); // Light blue/teal for active elements
  static const accent = Color(0xFFB8A7FF); // Light purple for gradients
  static const ring = Color(0xFF3A3F52); // Light gray for circular ring
  static const textPrimary = Color(0xFFFFFFFF); // White for primary text
  static const textSecondary = Color(0xFFB9C7D3); // Light gray for secondary text
  static const textTertiary = Color(0xFF8FA0AE); // Lighter gray for tertiary text
  static const success = Color(0xFF2DD4BF);
  static const navInactive = Color(0xFFFFFFFF); // White for inactive nav items
}

class Gaps {
  static const page = EdgeInsets.symmetric(horizontal: 24, vertical: 24);
  static const cardPadding = EdgeInsets.all(20);
}

class AppGradients {
  static const bar = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF4DD0E1), Color(0xFFB8A7FF)],
  );
  static const wakeUpButton = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFB8A7FF), Color(0xFF4DD0E1)],
  );
}
