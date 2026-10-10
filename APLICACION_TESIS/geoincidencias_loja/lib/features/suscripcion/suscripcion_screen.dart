import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/api_service.dart';
import '../../../core/theme.dart';
import '../../../models/freemium.dart';

/// Pantalla "Hazte VIP": muestra el plan del backend y permite activarlo o cancelarlo.
/// La pasarela de pago es SIMULADA: no se realiza ningún cobro real.
class SuscripcionScreen extends StatefulWidget {
  const SuscripcionScreen({super.key});

  @override
  State<SuscripcionScreen> createState() => _SuscripcionScreenState();
}

class _SuscripcionScreenState extends State<SuscripcionScreen> {
  static const Color _dorado = Color(0xFFF59E0B);

  final ApiService _api = ApiService();
  Suscripcion? _suscripcion;
  bool _cargando = true;
  bool _procesando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final s = await _api.obtenerSuscripcion();
      if (!mounted) return;
      setState(() {
        _suscripcion = s;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar la información del plan.';
        _cargando = false;
      });
    }
  }

  String _fecha(DateTime? f) =>
      f == null ? '-' : DateFormat('dd/MM/yyyy').format(f);

  void _aviso(String texto, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(texto), backgroundColor: color));
  }

  Future<void> _activar() async {
    setState(() => _procesando = true);
    try {
      final s = await _api.activarVip();
      if (!mounted) return;
      setState(() {
        _suscripcion = s;
        _procesando = false;
      });
      _aviso('⭐ VIP activo hasta el ${_fecha(s.vipHasta)}', Colors.teal);
    } catch (_) {
      if (!mounted) return;
      setState(() => _procesando = false);
      _aviso(
        'No se pudo activar la suscripción. Intenta de nuevo.',
        Colors.redAccent,
      );
    }
  }

  Future<void> _cancelar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar suscripción'),
        content: const Text(
          'Perderás el reporte anónimo, la atención prioritaria y volverás a ver anuncios.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Mantener VIP'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Cancelar suscripción',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _procesando = true);
    try {
      final s = await _api.cancelarVip();
      if (!mounted) return;
      setState(() {
        _suscripcion = s;
        _procesando = false;
      });
      _aviso('Suscripción cancelada.', Colors.blueGrey);
    } catch (_) {
      if (!mounted) return;
      setState(() => _procesando = false);
      _aviso('No se pudo cancelar. Intenta de nuevo.', Colors.redAccent);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          children: const [
            Text(
              'Suscripción VIP',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 2),
            Text(
              'Más privacidad y prioridad',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 50,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(_error!),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _cargar,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            )
          : _contenido(_suscripcion!),
    );
  }

  Widget _contenido(Suscripcion s) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _tarjetaPlan(s),
        if (s.esVip) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _dorado.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _dorado.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.workspace_premium, color: _dorado),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Suscripción activa hasta el ${_fecha(s.vipHasta)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        Text(
          'Qué incluye',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade900,
          ),
        ),
        const SizedBox(height: 10),
        for (final b in s.plan.beneficios)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppTheme.primario,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(b, style: const TextStyle(fontSize: 14.5)),
                ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        Text(
          'Un reporte anónimo oculta tu nombre y tu foto al público. '
          'El personal municipal autorizado conserva el registro para auditoría.',
          style: TextStyle(
            fontSize: 12.5,
            color: Colors.grey.shade600,
            height: 1.4,
          ),
        ),
        if (s.simulado) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: Colors.blueGrey.shade600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Versión de prueba: el pago está simulado y no se realiza ningún cobro.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.blueGrey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _procesando ? null : _activar,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primario,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _procesando
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    s.esVip
                        ? 'Extender ${s.plan.dias} días'
                        : 'Suscribirme por \$${s.plan.precioUsd}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        if (s.esVip)
          TextButton(
            onPressed: _procesando ? null : _cancelar,
            child: const Text(
              'Cancelar suscripción',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
      ],
    );
  }

  Widget _tarjetaPlan(Suscripcion s) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primarioOscuro, AppTheme.primario],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                s.plan.nombre,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${s.plan.precioUsd}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '/ ${s.plan.dias} días',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
