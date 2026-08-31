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

            return Marker(
              point: LatLng(lat, lng),
              width: 40,
              height: 40,
              child: GestureDetector(
                onTap: () => _mostrarDetalle(props),
                child: const Icon(
                  Icons.location_pin,
                  color: Colors.teal,
                  size: 40,
                ),
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
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              props['categoria'] ?? 'Sin categoría',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(props['descripcion'] ?? 'Sin descripción'),
            if (props['fecha_reporte'] != null) ...[
              const SizedBox(height: 8),
              Text(
                '📅 ${props['fecha_reporte']}',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ],
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
                  // ️ OPENSTREETMAP - GRATIS Y SIN API KEY
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.geoincidencias_loja',
                ),
                MarkerLayer(markers: _markers),
              ],
            ),
    );
  }
}
