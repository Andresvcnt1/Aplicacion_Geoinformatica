import 'dart:async';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/aparecer.dart';
import '../../core/theme.dart';
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

  // ============================================================
  // INTERFAZ: rediseñada como espejo del login y registro
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primarioOscuro, AppTheme.primario],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Aparecer(orden: 0, child: _logo()),
                const SizedBox(height: 22),
                Aparecer(
                  orden: 1,
                  child: const Text(
                    'GeoIncidencias Loja',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Aparecer(
                  orden: 2,
                  child: Text(
                    'Tu reporte transforma tu ciudad',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 14.5,
                    ),
                  ),
                ),
                const SizedBox(height: 46),
                Aparecer(orden: 3, child: _indicadorCarga()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _logo() {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Image.asset(
        'assets/images/logo.jpg',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(
            Icons.location_city,
            size: 64,
            color: AppTheme.primario,
          );
        },
      ),
    );
  }

  Widget _indicadorCarga() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Verificando sesión segura…',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
