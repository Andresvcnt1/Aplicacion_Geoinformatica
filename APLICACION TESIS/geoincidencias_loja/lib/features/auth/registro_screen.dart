import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../dashboard/home_screen.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cedulaController = TextEditingController();
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _cargando = false;
  String _metodoBiometrico = 'huella';

  // ✅ NUEVO: Variables para mostrar/ocultar contraseñas
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Validar cédula ecuatoriana
  bool validarCedula(String cedula) {
    if (cedula.length != 10 || !RegExp(r'^\d+$').hasMatch(cedula)) return false;
    final provincia = int.parse(cedula.substring(0, 2));
    if (provincia < 1 || provincia > 24) return false;
    if (int.parse(cedula[2]) > 5) return false;

    const coef = [2, 1, 2, 1, 2, 1, 2, 1, 2];
    int suma = 0;
    for (int i = 0; i < 9; i++) {
      int v = int.parse(cedula[i]) * coef[i];
      if (v > 9) v -= 9;
      suma += v;
    }
    return (10 - (suma % 10)) % 10 == int.parse(cedula[9]);
  }

  Future<void> _registrarUsuario() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Primero verificar biometría
    final biometriaOk = await _verificarBiometria();
    if (!biometriaOk) return;

    setState(() => _cargando = true);

    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/registro/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'cedula': _cedulaController.text.trim(),
          'first_name': _nombreController.text.trim().split(' ').first,
          'last_name': _nombreController.text.trim().split(' ').length > 1
              ? _nombreController.text.trim().split(' ').sublist(1).join(' ')
              : '',
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
          'password_confirm': _confirmPasswordController.text,
          'metodo_verificacion': _metodoBiometrico,
        }),
      );

      if (response.statusCode == 201) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cedula', _cedulaController.text.trim());
        await prefs.setBool('usuario_registrado', true);

        // ==========================================================
        // ✅ AUTO-LOGIN CORREGIDO (usa 'cedula' en lugar de 'username')
        // ==========================================================
        final loginResponse = await http.post(
          Uri.parse('${ApiConstants.baseUrl}/api/login/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'cedula': _cedulaController.text.trim(), // <-- CAMBIO CLAVE AQUÍ
            'password': _passwordController.text,
          }),
        );

        debugPrint('--- RESPUESTA AUTO-LOGIN ---');
        debugPrint('Status: ${loginResponse.statusCode}');
        debugPrint('Body: ${loginResponse.body}');
        debugPrint('--------------------------');

        if (loginResponse.statusCode == 200) {
          final loginData = jsonDecode(loginResponse.body);
          final token = loginData['access'] ?? loginData['token'] ?? '';
          final refreshToken = loginData['refresh'] ?? '';

          await prefs.setString('token', token);
          await prefs.setString('refresh_token', refreshToken);
          debugPrint('✅ Token guardado exitosamente');
        } else {
          debugPrint('⚠️ Auto-login falló. El perfil no cargará sin token.');
        }
        // ==========================================================

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        final error = jsonDecode(response.body);
        String mensaje = 'Error en el registro';

        if (error is Map) {
          mensaje = error.values.first
              .toString(); // Muestra el error real de Django
        }
        _showSnackBar('❌ $mensaje', Colors.red);
      }
    } catch (e) {
      _showSnackBar('❌ Error de conexión: $e', Colors.red);
    } finally {
      setState(() => _cargando = false);
    }
  }

  Future<bool> _verificarBiometria() async {
    final LocalAuthentication localAuth = LocalAuthentication();

    try {
      final bool canCheckBiometrics = await localAuth.canCheckBiometrics;

      if (!canCheckBiometrics) {
        _showSnackBar(
          '⚠️ No hay biometría configurada. Se omitirá este paso.',
          Colors.orange,
        );
        return true;
      }

      final List<BiometricType> availableBiometrics = await localAuth
          .getAvailableBiometrics();

      final bool tieneFacial = availableBiometrics.contains(BiometricType.face);
      setState(() {
        _metodoBiometrico = tieneFacial ? 'facial' : 'huella';
      });

      String mensaje = tieneFacial
          ? 'Usa tu reconocimiento facial o PIN para registrar tu cuenta'
          : 'Usa tu huella digital o PIN para registrar tu cuenta';

      final bool didAuthenticate = await localAuth.authenticate(
        localizedReason: mensaje,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );

      return didAuthenticate;
    } on LocalAuthException catch (e) {
      debugPrint('Código de error biometría: ${e.code.name}');

      if (e.code == LocalAuthExceptionCode.noBiometricHardware) {
        _showSnackBar(
          '⚠️ Este dispositivo no tiene sensor biométrico.',
          Colors.orange,
        );
      } else if (e.code == LocalAuthExceptionCode.temporaryLockout ||
          e.code == LocalAuthExceptionCode.biometricLockout) {
        _showSnackBar(
          '⚠️ Biometría bloqueada temporalmente. Intenta más tarde.',
          Colors.orange,
        );
      } else if (e.code == LocalAuthExceptionCode.userCanceled ||
          e.code == LocalAuthExceptionCode.systemCanceled) {
        _showSnackBar('⚠️ Autenticación cancelada.', Colors.orange);
      } else {
        _showSnackBar(
          '⚠️ No se pudo verificar la biometría. Se omitirá este paso.',
          Colors.orange,
        );
      }
      return true;
    } catch (e) {
      _showSnackBar(
        '⚠️ No se pudo verificar la biometría. Se omitirá este paso.',
        Colors.orange,
      );
      return true;
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00796B),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person_add,
                      size: 70,
                      color: Color(0xFF00796B),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Registro Ciudadano',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Completa tus datos para registrarte',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 20),

                    // Cédula
                    TextFormField(
                      controller: _cedulaController,
                      keyboardType: TextInputType.number,
                      maxLength: 10,
                      decoration: const InputDecoration(
                        labelText: 'Número de cédula',
                        prefixIcon: Icon(Icons.badge),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Ingresa tu cédula';
                        if (!validarCedula(v)) return 'Cédula inválida';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Nombre
                    TextFormField(
                      controller: _nombreController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Ingresa tu nombre';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Email
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Ingresa tu email';
                        if (!v.contains('@')) return 'Email inválido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // ✅ Contraseña con botón de ver/ocultar
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Ingresa contraseña';
                        if (v.length < 6) return 'Mínimo 6 caracteres';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // ✅ Confirmar contraseña con botón de ver/ocultar
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'Confirmar contraseña',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
                            });
                          },
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty)
                          return 'Confirma tu contraseña';
                        if (v != _passwordController.text) {
                          return 'Las contraseñas no coinciden';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Botón registrar
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00796B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _cargando ? null : _registrarUsuario,
                        icon: _cargando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.verified_user),
                        label: Text(
                          _cargando
                              ? 'Registrando...'
                              : 'Registrar con biometría',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
