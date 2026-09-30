import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../core/theme.dart';

class MapaIncidenciasScreen extends StatefulWidget {
  const MapaIncidenciasScreen({super.key});

  @override
  State<MapaIncidenciasScreen> createState() => _MapaIncidenciasScreenState();
}

class _MapaIncidenciasScreenState extends State<MapaIncidenciasScreen> {
  List<Marker> _markers = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _cargarIncidencias();
  }

  // Color del pin según estado (alias conservados; 3 base alineados a EstadoColors)
  Color _getColorPorEstado(String? estado) {
    if (estado == null) return AppTheme.primario;
    final e = estado.toLowerCase();
    if (e.contains('recibido') ||
        e.contains('pendiente') ||
        e.contains('nuevo')) {
      return EstadoColors.recibido;
    } else if (e.contains('proceso') || e.contains('revision')) {
      return EstadoColors.enProceso;
    } else if (e.contains('resuelto') ||
        e.contains('finalizado') ||
        e.contains('solucionado') ||
        e.contains('cerrado')) {
      return EstadoColors.solucionado;
    }
    return AppTheme.primario;
  }

  // Ícono del pin según categoría (mismo esquema que el feed de publicaciones)
  IconData _iconoCategoria(String? categoria) {
    switch ((categoria ?? '').toUpperCase()) {
      case 'AGUA':
        return Icons.water_drop;
      case 'VIAL':
        return Icons.construction;
      case 'LUZ':
        return Icons.lightbulb;
      default:
        return Icons.report_problem;
    }
  }

  Future<void> _cargarIncidencias() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/incidencias-geojson/'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List;

        setState(() {
          _markers = features.map((f) {
            final coords = f['geometry']['coordinates'] as List;
            final props = f['properties'];

            final double lat = (coords[1] is num) ? coords[1].toDouble() : 0.0;
            final double lng = (coords[0] is num) ? coords[0].toDouble() : 0.0;
            final String estado = props['estado'] ?? 'Desconocido';
            final Color colorPin = _getColorPorEstado(estado);
            final IconData iconoPin = _iconoCategoria(props['categoria']);

            return Marker(
              point: LatLng(lat, lng),
              width: 48,
              height: 48,
              child: _PinMarker(
                color: colorPin,
                icono: iconoPin,
                onTap: () => _mostrarDetalle(props),
              ),
            );
          }).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Error del servidor: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage =
            'Error de conexión. Verifica que el backend esté corriendo.';
        _isLoading = false;
      });
    }
  }

  void _mostrarDetalle(Map<String, dynamic> props) {
    final String? fotoUrl = props['foto_url'];
    final String estado = props['estado'] ?? 'Desconocido';
    final String categoria = props['categoria'] ?? 'Sin categoría';
    final Color colorEstado = _getColorPorEstado(estado);
    final IconData iconoCat = _iconoCategoria(props['categoria']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),

              // Pills categoría + estado
              Row(
                children: [
                  _Chip(
                    icono: iconoCat,
                    texto: categoria,
                    color: AppTheme.primario,
                  ),
                  const SizedBox(width: 8),
                  _Chip(
                    icono: Icons.flag_outlined,
                    texto: estado,
                    color: colorEstado,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Foto
              if (fotoUrl != null && fotoUrl.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      fotoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey.shade100,
                        child: const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: 40,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Colors.grey.shade100,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.primario,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Descripción
              Text(
                props['descripcion'] ?? 'Sin descripción',
                style: const TextStyle(fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 14),

              // Fecha
              Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(
                    props['fecha_reporte'] ?? 'Fecha desconocida',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;

    return Scaffold(
      body: Stack(
        children: [
          // Mapa SIEMPRE visible (incluso cargando)
          FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(
                -4.0085,
                -79.2239,
              ), // Centro de Loja (intacto)
              initialZoom: 13.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.geoincidencias_loja',
              ),
              MarkerLayer(markers: _markers),
            ],
          ),

          // Isla flotante superior
          // Isla flotante superior (gradiente, igual que Publicaciones)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primarioOscuro, AppTheme.primario],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    if (canPop)
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        visualDensity: VisualDensity.compact,
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(Icons.location_city, color: Colors.white),
                      ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            'Mapa de Incidencias',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Reportes ciudadanos georreferenciados',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _isLoading ? null : _cargarIncidencias,
                      tooltip: 'Actualizar',
                      icon: Icon(
                        Icons.refresh,
                        color: _isLoading ? Colors.white54 : Colors.white,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Leyenda inferior-izquierda
          Positioned(
            left: 12,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  _LeyendaItem(color: EstadoColors.recibido, texto: 'Recibido'),
                  SizedBox(height: 6),
                  _LeyendaItem(
                    color: EstadoColors.enProceso,
                    texto: 'En proceso',
                  ),
                  SizedBox(height: 6),
                  _LeyendaItem(
                    color: EstadoColors.solucionado,
                    texto: 'Solucionado',
                  ),
                ],
              ),
            ),
          ),

          // Overlay de carga
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.white.withValues(alpha: 0.45),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppTheme.primario),
                      SizedBox(height: 12),
                      Text(
                        'Cargando incidencias…',
                        style: TextStyle(color: Colors.black87, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Overlay de error
          if (!_isLoading && _errorMessage != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 90,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi_off, color: Colors.red.shade400, size: 30),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13.5, height: 1.3),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _cargarIncidencias,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Reintentar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primario,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PinMarker extends StatelessWidget {
  final Color color;
  final IconData icono;
  final VoidCallback onTap;
  const _PinMarker({
    required this.color,
    required this.icono,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.30),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icono, color: Colors.white, size: 17),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icono;
  final String texto;
  final Color color;
  const _Chip({required this.icono, required this.texto, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            texto,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeyendaItem extends StatelessWidget {
  final Color color;
  final String texto;
  const _LeyendaItem({required this.color, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Text(
          texto,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
