import 'package:flutter/material.dart';

class WeatherPalettes {
  static const List<Color> lstColors = [
    Color(0xFF3B82F6),
    Color(0xFF10B981),
    Color(0xFF84CC16),
    Color(0xFFFACC15),
    Color(0xFFF97316),
    Color(0xFFEF4444),
    Color(0xFFB91C1C),
    Color(0xFF7C3AED),
  ];

  static const List<Color> rainColors = [
    Colors.transparent,
    Color(0xFFBAE6FD),
    Color(0xFF7DD3FC),
    Color(0xFF38BDF8),
    Color(0xFF0284C7),
    Color(0xFF0C4A6E),
  ];

  static Color getColorForTemp(double temp) {
    if (temp < 24) return lstColors[0];
    if (temp < 26) return lstColors[1];
    if (temp < 28) return lstColors[2];
    if (temp < 30) return lstColors[3];
    if (temp < 32) return lstColors[4];
    if (temp < 34) return lstColors[5];
    if (temp < 36) return lstColors[6];
    return lstColors[7];
  }

  static Color getColorForRain(double precip) {
    if (precip <= 0.0) return Colors.transparent;
    if (precip < 0.2) return rainColors[1];
    if (precip < 1.0) return rainColors[2];
    if (precip < 3.0) return rainColors[3];
    if (precip < 10.0) return rainColors[4];
    return rainColors[5];
  }
}