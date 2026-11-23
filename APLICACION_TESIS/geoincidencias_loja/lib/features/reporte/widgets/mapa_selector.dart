import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme.dart';

/// Pantalla para seleccionar una ubicación en el mapa
class MapaSelectorScreen extends StatefulWidget {
  final LatLng? ubicacionInicial;

  const MapaSelectorScreen({
    super.key,
    this.ubicacionInicial,
  });

  @override
  State<MapaSelectorScreen> createState() => _MapaSelectorScreenState();
}

class _MapaSelectorScreenState extends State<MapaSelectorScreen> {
  final MapController _mapController = MapController();
  LatLng? _ubicacionSeleccionada;
  bool _cargandoUbicacion = false;

  @override
  void initState() {
    super.initState();
    _ubicacionSeleccionada = widget.ubicacionInicial;
  }

  Future<void> _obtenerMiUbicacion() async {
    setState(() => _cargandoUbicacion = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Activa el GPS en tu dispositivo')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permiso de ubicación denegado')),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permiso de ubicación denegado permanentemente')),
        );
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;

      final nuevaUbicacion = LatLng(position.latitude, position.longitude);
      setState(() {
        _ubicacionSeleccionada = nuevaUbicacion;
      });

      _mapController.move(nuevaUbicacion, 16.0);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ubicación actualizada a tu posición'),
          backgroundColor: Colors.teal,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _cargandoUbicacion = false);
    }
  }

  void _confirmarUbicacion() {
    if (_ubicacionSeleccionada != null) {
      Navigator.pop(context, _ubicacionSeleccionada);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Toca el mapa para seleccionar una ubicación'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Centro por defecto: Loja
    final LatLng centroInicial = _ubicacionSeleccionada ?? const LatLng(-4.0085, -79.2239);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar en el mapa'),
        backgroundColor: AppTheme.primario,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _cargandoUbicacion ? null : _obtenerMiUbicacion,
            tooltip: 'Mi ubicación',
            icon: _cargandoUbicacion
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.my_location),
          ),
          IconButton(
            onPressed: _confirmarUbicacion,
            tooltip: 'Confirmar',
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: centroInicial,
              initialZoom: 15.0,
              onTap: (_, punto) {
                setState(() {
                  _ubicacionSeleccionada = punto;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.geoincidencias_loja',
              ),
              if (_ubicacionSeleccionada != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _ubicacionSeleccionada!,
                      width: 50,
                      height: 50,
                      child: _MarcadorSeleccion(),
                    ),
                  ],
                ),
            ],
          ),

          // Instrucciones
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _ubicacionSeleccionada == null
                        ? 'Toca el mapa para marcar la ubicación'
                        : 'Lat: ${_ubicacionSeleccionada!.latitude.toStringAsFixed(6)}\nLng: ${_ubicacionSeleccionada!.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),

          // Botón confirmar inferior
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _confirmarUbicacion,
                    icon: const Icon(Icons.check_circle, size: 22),
                    label: Text(
                      _ubicacionSeleccionada == null
                          ? 'Selecciona una ubicación'
                          : 'Confirmar ubicación',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          _ubicacionSeleccionada == null ? Colors.grey : AppTheme.primario,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarcadorSeleccion extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulso animado
        const _PulsoAnimado(),
        // Pin principal
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.primario,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(Icons.location_on, color: Colors.white, size: 22),
        ),
      ],
    );
  }
}

class _PulsoAnimado extends StatefulWidget {
  const _PulsoAnimado();

  @override
  State<_PulsoAnimado> createState() => _PulsoAnimadoState();
}

class _PulsoAnimadoState extends State<_PulsoAnimado>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 2.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _opacityAnimation = Tween<double>(begin: 0.5, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Container(
          width: 36 * _scaleAnimation.value,
          height: 36 * _scaleAnimation.value,
          decoration: BoxDecoration(
            color: AppTheme.primario.withValues(alpha: _opacityAnimation.value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}