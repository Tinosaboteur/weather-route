import 'package:flutter/material.dart';

class CustomColors extends ThemeExtension<CustomColors> {
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  const CustomColors({
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
  });

  @override
  CustomColors copyWith({Color? success, Color? warning, Color? danger, Color? info}) {
    return CustomColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
    );
  }

  @override
  CustomColors lerp(ThemeExtension<CustomColors>? other, double t) {
    if (other is! CustomColors) return this;
    return CustomColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }

  static const light = CustomColors(
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFEF4444),
    info: Color(0xFF3B82F6),
  );

  static const dark = CustomColors(
    success: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    danger: Color(0xFFF87171),
    info: Color(0xFF60A5FA),
  );
}

class AppTheme {
  static const primaryColor = Color(0xFF2563EB);
  static const secondaryColor = Color(0xFF0EA5E9);

  static LinearGradient primaryGradient({bool reversed = false}) => LinearGradient(
    begin: reversed ? Alignment.topRight : Alignment.topLeft,
    end: reversed ? Alignment.bottomLeft : Alignment.bottomRight,
    colors: const [Color(0xFF2563EB), Color(0xFF0EA5E9)],
  );

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: const Color(0xFFF1F5F9),
    cardColor: Colors.white,
    dividerColor: const Color(0xFFE2E8F0),
    colorScheme: const ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      surface: Colors.white,
      background: Color(0xFFF1F5F9),
      onPrimary: Colors.white,
      onSurface: Color(0xFF1E293B),
      error: Color(0xFFEF4444),
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Color(0xFF1E293B),
      centerTitle: true,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w500),
      bodyMedium: TextStyle(color: Color(0xFF334155)),
      bodySmall: TextStyle(color: Color(0xFF64748B)),
      titleLarge: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
    ),
    extensions: const [CustomColors.light],
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: const Color(0xFF0F172A),
    cardColor: const Color(0xFF1E293B),
    dividerColor: const Color(0xFF334155),
    colorScheme: const ColorScheme.dark(
      primary: primaryColor,
      secondary: secondaryColor,
      surface: Color(0xFF1E293B),
      background: Color(0xFF0F172A),
      onPrimary: Colors.white,
      onSurface: Color(0xFFF8FAFC),
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Color(0xFFF8FAFC),
      centerTitle: true,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Color(0xFFF8FAFC), fontWeight: FontWeight.w500),
      bodyMedium: TextStyle(color: Color(0xFFE2E8F0)),
      bodySmall: TextStyle(color: Color(0xFF94A3B8)),
      titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    ),
    extensions: const [CustomColors.dark],
  );
}