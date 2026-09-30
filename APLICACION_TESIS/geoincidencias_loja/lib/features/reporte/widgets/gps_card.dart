import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme.dart';

/// Tarjeta de estado de la ubicación GPS. No obtiene la ubicación por sí
/// misma: solo muestra el estado que le pasa ReporteScreen y avisa con
/// `onTap` cuando la persona quiere obtenerla o reintentar.
class GpsCard extends StatelessWidget {
  final bool cargando;
  final Position? posicion;
  final bool tieneError;
  final String? mensajeError;
  final VoidCallback onTap;

  const GpsCard({
    super.key,
    required this.cargando,
    required this.posicion,
    required this.tieneError,
    required this.onTap,
    this.mensajeError,
  });

  @override
  Widget build(BuildContext context) {
    final listo = posicion != null;
    final color = listo
        ? AppTheme.primario
        : (tieneError ? Colors.red.shade600 : Colors.grey.shade400);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: listo
            ? AppTheme.primario.withValues(alpha: 0.06)
            : (tieneError ? Colors.red.withValues(alpha: 0.05) : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: listo || tieneError ? 2 : 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: cargando
                    ? const SizedBox(
                        key: ValueKey('spinner'),
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: AppTheme.primario,
                        ),
                      )
                    : Icon(
                        listo
                            ? Icons.check_circle
                            : (tieneError
                                  ? Icons.location_off
                                  : Icons.location_searching),
                        key: ValueKey(
                          listo ? 'ok' : (tieneError ? 'error' : 'idle'),
                        ),
                        color: color,
                        size: 24,
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ubicación GPS',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: listo
                        ? AppTheme.primarioOscuro
                        : Colors.grey.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _mensaje(listo),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: cargando ? null : onTap,
              icon: cargando
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(listo ? Icons.refresh : Icons.my_location, size: 18),
              label: Text(
                cargando
                    ? 'Buscando señal...'
                    : (listo
                          ? 'Actualizar ubicación'
                          : 'Obtener ubicación actual'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primario,
                side: const BorderSide(color: AppTheme.primario),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mensaje(bool listo) {
    if (listo) {
      return Container(
        key: const ValueKey('listo'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.primario.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.place, size: 16, color: AppTheme.primario),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Lat: ${posicion!.latitude.toStringAsFixed(6)}   '
                'Lng: ${posicion!.longitude.toStringAsFixed(6)}',
                style: const TextStyle(fontSize: 12.5, color: Colors.black87),
              ),
            ),
          ],
        ),
      );
    }

    if (tieneError) {
      return Text(
        key: const ValueKey('error'),
        mensajeError ?? 'No se pudo obtener tu ubicación',
        style: TextStyle(fontSize: 13, color: Colors.red.shade700),
      );
    }

    return Text(
      key: const ValueKey('idle'),
      'Necesitamos tu ubicación para registrar el reporte en el mapa',
      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
    );
  }
}
