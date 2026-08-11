import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'features/dashboard/home_screen.dart';

void main() => runApp(const GeoIncidenciasApp());

class GeoIncidenciasApp extends StatelessWidget {
  const GeoIncidenciasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeoIncidencias Loja',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const HomeScreen(),
    );
  }
}
