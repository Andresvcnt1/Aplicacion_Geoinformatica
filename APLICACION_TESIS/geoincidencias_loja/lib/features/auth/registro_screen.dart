import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/aparecer.dart';
import '../../core/theme.dart';
import '../dashboard/home_screen.dart';
import 'login_screen.dart';

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

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // ============================================================
  // LÓGICA: SIN CAMBIOS respecto a la versión anterior
  // ============================================================

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

    // Primero verificar biometría (orden intencional: setea _metodoBiometrico
    // ANTES del POST, no mover)
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
        // AUTO-LOGIN CORREGIDO (usa 'cedula' en lugar de 'username')
        // ==========================================================
        final loginResponse = await http.post(
          Uri.parse('${ApiConstants.baseUrl}/api/login/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'cedula': _cedulaController.text.trim(),
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
          mensaje = error.values.first.toString();
        }
        _showSnackBar('❌ $mensaje', Colors.redAccent);
      }
    } catch (e) {
      _showSnackBar('❌ Error de conexión: $e', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _cargando = false);
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    _cedulaController.dispose();
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ============================================================
  // INTERFAZ: rediseñada como espejo del login
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Aparecer(orden: 0, child: _logo()),
                    const SizedBox(height: 24),
                    Aparecer(orden: 1, child: _tarjetaFormulario()),
                    const SizedBox(height: 20),
                    Aparecer(orden: 2, child: _linkLogin()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _logo() {
    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.person_add_alt_1,
            size: 44,
            color: AppTheme.primario,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Crear cuenta',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Únete a GeoIncidencias Loja',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _tarjetaFormulario() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Registro ciudadano',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.grey.shade900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Completa tus datos para reportar incidencias',
              style: TextStyle(fontSize: 13.5, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 22),

            // Cédula
            _campoLabel('Cédula'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _cedulaController,
              keyboardType: TextInputType.number,
              maxLength: 10,
              decoration: _decoracionCampo(
                hint: '10 dígitos',
                icono: Icons.badge_outlined,
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Ingresa tu cédula';
                if (!validarCedula(v)) return 'Cédula inválida';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Nombre
            _campoLabel('Nombre completo'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nombreController,
              textCapitalization: TextCapitalization.words,
              decoration: _decoracionCampo(
                hint: 'Ej: Andrés González',
                icono: Icons.person_outline,
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Ingresa tu nombre';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Email
            _campoLabel('Correo electrónico'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: _decoracionCampo(
                hint: 'correo@ejemplo.com',
                icono: Icons.mail_outline,
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Ingresa tu email';
                if (!v.contains('@')) return 'Email inválido';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Contraseña
            _campoLabel('Contraseña'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: _decoracionCampo(
                hint: 'Mínimo 8 caracteres',
                icono: Icons.lock_outline,
                sufijo: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: Colors.grey.shade500,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Ingresa una contraseña';
                if (v.length < 8)
                  return 'La contraseña debe tener al menos 8 caracteres';
                if (!RegExp(r'[A-Za-z]').hasMatch(v))
                  return 'Debe contener al menos una letra (no solo números)';
                if (RegExp(
                  r'^(12345678|password|qwerty123)$',
                  caseSensitive: false,
                ).hasMatch(v)) {
                  return 'Esta contraseña es demasiado común y no es segura';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Confirmar contraseña
            _campoLabel('Confirmar contraseña'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              decoration: _decoracionCampo(
                hint: 'Repite la contraseña',
                icono: Icons.lock_reset_outlined,
                sufijo: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: Colors.grey.shade500,
                    size: 20,
                  ),
                  onPressed: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  ),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Confirma tu contraseña';
                if (v != _passwordController.text) {
                  return 'Las contraseñas no coinciden';
                }
                return null;
              },
            ),
            const SizedBox(height: 26),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primario,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _cargando ? null : _registrarUsuario,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _cargando
                      ? const SizedBox(
                          key: ValueKey('cargando'),
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.4,
                          ),
                        )
                      : const Row(
                          key: ValueKey('idle'),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              size: 20,
                              color: Colors.white,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Registrar con biometría',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _campoLabel(String texto) {
    return Text(
      texto,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade700,
      ),
    );
  }

  InputDecoration _decoracionCampo({
    required String hint,
    required IconData icono,
    Widget? sufijo,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      counterText: '',
      prefixIcon: Icon(icono, size: 20, color: Colors.grey.shade500),
      suffixIcon: sufijo,
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primario, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }

  Widget _linkLogin() {
    return TextButton(
      onPressed: _cargando
          ? null
          : () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 13.5,
          ),
          children: const [
            TextSpan(text: '¿Ya tienes cuenta? '),
            TextSpan(
              text: 'Inicia sesión',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
