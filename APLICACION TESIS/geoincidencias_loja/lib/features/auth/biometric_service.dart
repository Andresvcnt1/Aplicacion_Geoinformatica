import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> autenticarUsuario() async {
    try {
      final bool puedeAutenticar =
          await _auth.canCheckBiometrics || await _auth.isDeviceSupported();

      if (!puedeAutenticar) {
        debugPrint(
          'Dispositivo sin seguridad configurada. Permitiendo acceso por compatibilidad.',
        );
        return true;
      }

      return await _auth.authenticate(
        localizedReason:
            'Verifica tu identidad para enviar el reporte de incidencia.',
        biometricOnly: false,
      );
    } catch (e) {
      debugPrint('Error en autenticación biométrica: $e');
      return false;
    }
  }
}
