import 'dart:async';
import 'package:flutter/material.dart';
import '../auth/registro_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    print('⏳ SPLASH INICIADO');
    // Espera 3 segundos y va al registro (sin validar prefs por ahora)
    Timer(const Duration(seconds: 3), () {
      print('🚀 NAVEGANDO AL REGISTRO...');
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RegistroScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    print('🎨 DIBUJANDO SPLASH...');
    return Scaffold(
      backgroundColor: const Color(0xFF00796B),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Si el logo falla, mostrará el ícono de respaldo automáticamente
            Image.asset(
              'assets/images/logo.jpg',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                print('⚠️ Logo no encontrado, usando ícono de respaldo');
                return const Icon(
                  Icons.location_city,
                  size: 120,
                  color: Colors.white,
                );
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'GeoIncidencias Loja',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tu reporte transforma tu ciudad',
              style: TextStyle(color: Colors.white70, fontSize: 15),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
