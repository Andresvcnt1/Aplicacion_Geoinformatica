import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> autenticarUsuario() async {
    try {
      // Verificamos si el dispositivo soporta biometría O métodos alternativos (PIN/Patrón)
      final bool puedeAutenticar = await _auth.canCheckBiometrics || 
                                   await _auth.isDeviceSupported();
      
      if (!puedeAutenticar) return true; // Fallback: permitir pasar si no hay seguridad disponible

      return await _auth.authenticate(
        localizedReason: 'Verifica tu identidad para enviar el reporte de incidencia.',
        // Permitir credenciales biométricas o de dispositivo (PIN/Patrón)
        biometricOnly: false,
      );
    } catch (e) {
      debugPrint('Error en autenticación biométrica: $e');
      return false;
    }
  }
}