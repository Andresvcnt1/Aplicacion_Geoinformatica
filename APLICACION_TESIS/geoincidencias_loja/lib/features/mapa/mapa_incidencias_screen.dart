import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';

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

  // Función para determinar el color del pin según el estado
  Color _getColorPorEstado(String? estado) {
    if (estado == null) return Colors.teal;
    final e = estado.toLowerCase();
    if (e.contains('recibido') ||
        e.contains('pendiente') ||
        e.contains('nuevo')) {
      return Colors.red;
    } else if (e.contains('proceso') || e.contains('revision')) {
      return Colors.orange;
    } else if (e.contains('resuelto') ||
        e.contains('finalizado') ||
        e.contains('cerrado')) {
      return Colors.green;
    }
    return Colors.teal; // Color por defecto
  }

  Future<void> _cargarIncidencias() async {
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

            return Marker(
              point: LatLng(lat, lng),
              width: 40,
              height: 40,
              child: GestureDetector(
                onTap: () => _mostrarDetalle(props),
                child: Icon(Icons.location_pin, color: colorPin, size: 45),
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
            'Error de conexión. Verifica que el backend esté corriendo.\n$e';
        _isLoading = false;
      });
    }
  }

  void _mostrarDetalle(Map<String, dynamic> props) {
    final String? fotoUrl = props['foto_url'];
    final String estado = props['estado'] ?? 'Desconocido';
    final Color colorEstado = _getColorPorEstado(estado);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado con Categoría y Estado
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      props['categoria'] ?? 'Sin categoría',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colorEstado.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colorEstado, width: 1.5),
                    ),
                    child: Text(
                      estado,
                      style: TextStyle(
                        color: colorEstado,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Foto de la incidencia (si existe)
              if (fotoUrl != null && fotoUrl.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    fotoUrl,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: Colors.grey.shade200,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image,
                              size: 50,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Error al cargar imagen',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 200,
                        color: Colors.grey.shade200,
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Descripción
              const Text(
                'Descripción:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                props['descripcion'] ?? 'Sin descripción',
                style: const TextStyle(fontSize: 15),
              ),

              const SizedBox(height: 16),

              // Fecha
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    props['fecha_reporte'] ?? 'Fecha desconocida',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de Incidencias Loja'),
        backgroundColor: Colors.teal,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
              ),
            )
          : FlutterMap(
              options: const MapOptions(
                initialCenter: LatLng(-4.0085, -79.2239), // Centro de Loja
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
    );
  }
}
