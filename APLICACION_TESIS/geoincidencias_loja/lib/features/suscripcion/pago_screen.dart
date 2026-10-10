import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/api_service.dart';
import '../../core/theme.dart';
import '../../models/freemium.dart';

/// Checkout de la suscripción VIP con tarjeta.
///
/// Seguridad: el número completo y el CVV solo existen en este formulario y se
/// descartan al salir. Al servidor únicamente viajan la marca y los últimos 4
/// dígitos. Cuando la pasarela es simulada, solo se aceptan tarjetas de prueba.
///
/// Devuelve (Navigator.pop) la [Suscripcion] actualizada si el pago fue aprobado.
class PagoScreen extends StatefulWidget {
  final Suscripcion suscripcion;
  const PagoScreen({super.key, required this.suscripcion});

  @override
  State<PagoScreen> createState() => _PagoScreenState();
}

class _PagoScreenState extends State<PagoScreen> {
  /// Tarjetas de prueba aceptadas mientras la pasarela sea simulada.
  static const Map<String, String> _tarjetasPrueba = {
    '4242424242424242': 'Visa (aprobada)',
    '5555555555554444': 'Mastercard (aprobada)',
    '4000000000000002': 'Visa (rechazada)',
  };

  final _formKey = GlobalKey<FormState>();
  final _titular = TextEditingController();
  final _numero = TextEditingController();
  final _vencimiento = TextEditingController();
  final _cvv = TextEditingController();
  final ApiService _api = ApiService();

  bool _procesando = false;
  String? _errorPago;

  @override
  void dispose() {
    _titular.dispose();
    _numero.dispose();
    _vencimiento.dispose();
    _cvv.dispose();
    super.dispose();
  }

  String get _digitos => _numero.text.replaceAll(RegExp(r'\D'), '');

  static String _marcaDe(String d) {
    if (d.startsWith('4')) return 'visa';
    if (RegExp(
      r'^(5[1-5]|222[1-9]|22[3-9]\d|2[3-6]\d\d|27[01]\d|2720)',
    ).hasMatch(d)) {
      return 'mastercard';
    }
    if (RegExp(r'^3[47]').hasMatch(d)) return 'amex';
    return 'otra';
  }

  static bool _luhn(String d) {
    var suma = 0;
    var alterna = false;
    for (var i = d.length - 1; i >= 0; i--) {
      var n = int.parse(d[i]);
      if (alterna) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      suma += n;
      alterna = !alterna;
    }
    return suma % 10 == 0;
  }

  static String _agrupar(String digitos) =>
      RegExp(r'.{1,4}').allMatches(digitos).map((m) => m.group(0)!).join(' ');

  void _rellenar(String numero) {
    final yy = ((DateTime.now().year + 3) % 100).toString().padLeft(2, '0');
    setState(() {
      _titular.text = 'USUARIO DE PRUEBA';
      _numero.text = _agrupar(numero);
      _vencimiento.text = '12/$yy';
      _cvv.text = '123';
      _errorPago = null;
    });
  }

  String? _validarTitular(String? v) {
    if (v == null || v.trim().length < 3)
      return 'Ingresa el nombre del titular';
    return null;
  }

  String? _validarNumero(String? v) {
    final d = _digitos;
    if (d.length < 13 || d.length > 19) return 'Número de tarjeta incompleto';
    if (!_luhn(d)) return 'Número de tarjeta inválido';
    if (widget.suscripcion.simulado && !_tarjetasPrueba.containsKey(d)) {
      return 'Modo de prueba: usa una tarjeta de prueba';
    }
    return null;
  }

  String? _validarVencimiento(String? v) {
    final texto = v ?? '';
    if (!RegExp(r'^(0[1-9]|1[0-2])/\d{2}$').hasMatch(texto)) {
      return 'Usa el formato MM/AA';
    }
    final mes = int.parse(texto.substring(0, 2));
    final anio = 2000 + int.parse(texto.substring(3, 5));
    // Vigente hasta el último día del mes indicado
    if (!DateTime(anio, mes + 1, 1).isAfter(DateTime.now())) {
      return 'Tarjeta vencida';
    }
    return null;
  }

  String? _validarCvv(String? v) {
    final largo = _marcaDe(_digitos) == 'amex' ? 4 : 3;
    if (v == null || !RegExp('^\\d{$largo}\$').hasMatch(v)) {
      return 'CVV de $largo dígitos';
    }
    return null;
  }

  Future<void> _pagar() async {
    if (_procesando) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final d = _digitos;
    setState(() {
      _procesando = true;
      _errorPago = null;
    });
    try {
      final s = await _api.pagarSuscripcion(
        marca: _marcaDe(d),
        ultimos4: d.substring(d.length - 4),
      );
      if (!mounted) return;
      Navigator.pop(context, s);
    } on PagoException catch (e) {
      if (!mounted) return;
      setState(() {
        _procesando = false;
        _errorPago = e.mensaje;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _procesando = false;
        _errorPago =
            'No se pudo conectar con el servidor. Revisa tu internet e intenta de nuevo.';
      });
    }
  }

  InputDecoration _decoracion(
    String etiqueta, {
    String? hint,
    IconData? icono,
  }) {
    return InputDecoration(
      labelText: etiqueta,
      hintText: hint,
      prefixIcon: icono == null ? null : Icon(icono, size: 20),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.suscripcion;
    return Scaffold(
      backgroundColor: AppTheme.fondo,
      appBar: AppBar(
        toolbarHeight: 64,
        elevation: 1,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primarioOscuro, AppTheme.primario],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Método de pago',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              s.simulado ? 'Pago de prueba (simulado)' : 'Pago con tarjeta',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _resumen(s),
            if (s.simulado) ...[const SizedBox(height: 14), _bannerPrueba()],
            const SizedBox(height: 20),
            Text(
              'Datos de la tarjeta',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade900,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titular,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.next,
              decoration: _decoracion(
                'Titular',
                hint: 'Como aparece en la tarjeta',
                icono: Icons.person_outline,
              ),
              validator: _validarTitular,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _numero,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              inputFormatters: [_NumeroTarjetaFormatter()],
              decoration: _decoracion(
                'Número de tarjeta',
                hint: '0000 0000 0000 0000',
                icono: Icons.credit_card,
              ),
              validator: _validarNumero,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _vencimiento,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [_VencimientoFormatter()],
                    decoration: _decoracion('Vence', hint: 'MM/AA'),
                    validator: _validarVencimiento,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _cvv,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: _decoracion('CVV', hint: '123'),
                    validator: _validarCvv,
                    onFieldSubmitted: (_) => _pagar(),
                  ),
                ),
              ],
            ),
            if (_errorPago != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorPago!,
                        style: TextStyle(
                          color: Colors.red.shade800,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _procesando ? null : _pagar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primario,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _procesando
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Procesando pago...'),
                        ],
                      )
                    : Text(
                        'Pagar \$${s.plan.precioUsd}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'El número de tu tarjeta y el CVV no se envían ni se guardan. '
                    'Solo se registra la marca y los últimos 4 dígitos.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _resumen(Suscripcion s) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.workspace_premium,
              color: Color(0xFFF59E0B),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.plan.nombre,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '${s.plan.dias} días de acceso',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Text(
            '\$${s.plan.precioUsd}',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
          ),
        ],
      ),
    );
  }

  Widget _bannerPrueba() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: Colors.blueGrey.shade600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pago simulado: no se realiza ningún cobro real. '
                  'Usa una tarjeta de prueba, no ingreses una tarjeta real.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.blueGrey.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final e in _tarjetasPrueba.entries)
                ActionChip(
                  label: Text(e.value, style: const TextStyle(fontSize: 12)),
                  onPressed: _procesando ? null : () => _rellenar(e.key),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Formatea el número de tarjeta en grupos de 4 dígitos (máx. 19 dígitos).
class _NumeroTarjetaFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var d = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (d.length > 19) d = d.substring(0, 19);
    final texto = RegExp(
      r'.{1,4}',
    ).allMatches(d).map((m) => m.group(0)!).join(' ');
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

/// Formatea el vencimiento como MM/AA.
class _VencimientoFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var d = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (d.length > 4) d = d.substring(0, 4);
    final texto = d.length >= 3 ? '${d.substring(0, 2)}/${d.substring(2)}' : d;
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}
