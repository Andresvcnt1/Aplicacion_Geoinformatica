import 'dart:async';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/login_screen.dart';
import '../dashboard/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Pequeña espera para mostrar el splash antes de decidir a dónde ir
    Timer(const Duration(seconds: 2), _decidirRuta);
  }

  Future<void> _decidirRuta() async {
    final prefs = await SharedPreferences.getInstance();

    // ✅ CAMBIO CLAVE: Verificamos la existencia del token en lugar de 'sesion_activa'
    final token = prefs.getString('token');

    if (!mounted) return;

    // Si no hay token, el usuario no ha iniciado sesión o cerró sesión
    if (token == null || token.isEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    // ✅ Hay token válido: pedimos biometría para entrar directamente
    final bool autenticado = await _verificarBiometria();

    if (!mounted) return;

    if (autenticado) {
      // Biometría exitosa -> Home directo
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      // Biometría fallida, cancelada o no disponible -> Ir al Login para usar contraseña
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  Future<bool> _verificarBiometria() async {
    final LocalAuthentication localAuth = LocalAuthentication();

    try {
      final bool canCheckBiometrics = await localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await localAuth.isDeviceSupported();

      if (!canCheckBiometrics || !isDeviceSupported) {
        // Sin biometría disponible: dejamos pasar al login normal por seguridad
        return false;
      }

      final bool didAuthenticate = await localAuth.authenticate(
        localizedReason:
            'Usa tu huella, rostro o PIN para acceder a GeoIncidencias Loja',
        biometricOnly: false, // Permite usar PIN/patrón si la huella falla
        persistAcrossBackgrounding: true,
      );

      return didAuthenticate;
    } on LocalAuthException catch (e) {
      debugPrint('Error de biometría: ${e.code.name}');
      return false;
    } catch (e) {
      debugPrint('Error inesperado de biometría: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00796B),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.jpg',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
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
