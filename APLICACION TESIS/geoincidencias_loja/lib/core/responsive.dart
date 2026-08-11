import 'package:flutter/material.dart';

class Responsive {
  static double getWidth(BuildContext context, double percentage) {
    return MediaQuery.of(context).size.width * percentage;
  }

  static double getHeight(BuildContext context, double percentage) {
    return MediaQuery.of(context).size.height * percentage;
  }

  // Tamaños de fuente adaptativos
  static double getFontSize(BuildContext context, double baseSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 360) return baseSize * 0.85; // Celulares pequeños
    if (screenWidth > 600) return baseSize * 1.2; // Tablets
    return baseSize;
  }

  // Espaciado adaptable
  static EdgeInsets getPadding(BuildContext context, double factor) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    return EdgeInsets.all(factor * (isTablet ? 1.5 : 1.0));
  }
}
