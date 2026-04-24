import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF0F2C59); // Navy
  static const Color accent = Color(0xFF00BFA5);  // Teal
  static const Color navy = primary;
  static const Color teal = accent;
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Colors.white;
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF388E3C);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textMuted = Color(0xFF78909C);
  static const Color tealLight = Color(0xFFE0F8F4);
  static const Color tealDark = Color(0xFF00796B);
  static const Color border = Color(0xFFE6EBF2);
}

class AppRadius {
  static const double lg = 14;
  static const double full = 999;
}

class AppConstants {
  static const String appName = 'Temple Clock';
  
  // API Configuration
  // For Android Emulator, use 10.0.2.2 instead of localhost
  // For iOS Simulator or Web, use localhost
  static const String apiBaseUrl = 'https://temple-clock-staff-rota.onrender.com/api';
  
  // Storage Keys
  static const String tokenKey = 'jwt_token';
  static const String userKey = 'user_data';
}
