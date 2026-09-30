import 'package:flutter/material.dart';

/// Colores de estado. Son los mismos en la app móvil, el panel Django y el
/// panel Next.js: rojo = Recibido, naranja = En proceso, verde = Solucionado.
class EstadoColors {
  static const Color recibido = Color(0xFFE53935);
  static const Color enProceso = Color(0xFFFB8C00);
  static const Color solucionado = Color(0xFF43A047);
}

class AppTheme {
  static const Color primario = Color(0xFF00796B);
  static const Color primarioOscuro = Color(0xFF004D40);
  static const Color fondo = Color(0xFFF4F7F6);

  static ThemeData get lightTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: primario,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      primaryColor: primario,
      scaffoldBackgroundColor: fondo,
      appBarTheme: const AppBarTheme(
        backgroundColor: primario,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primario,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 4,
        height: 68,
        indicatorColor: primario.withValues(alpha: 0.14),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final seleccionado = states.contains(WidgetState.selected);
          return IconThemeData(
            color: seleccionado ? primario : Colors.grey.shade600,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final seleccionado = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: seleccionado ? FontWeight.w700 : FontWeight.w500,
            color: seleccionado ? primario : Colors.grey.shade600,
          );
        }),
      ),
    );
  }
}
