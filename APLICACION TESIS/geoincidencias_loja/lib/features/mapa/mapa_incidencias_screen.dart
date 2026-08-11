import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants.dart'; // Para obtener la URL base

class MapaIncidenciasScreen extends StatefulWidget {
  const MapaIncidenciasScreen({super.key});

  @override
  State<MapaIncidenciasScreen> createState() => _MapaIncidenciasScreenState();
}

class _MapaIncidenciasScreenState extends State<MapaIncidenciasScreen> {
  List<Marker> _markers = [];
  bool _isLoading = true;

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
            return Marker(
              point: LatLng(coords[1], coords[0]), // Lat, Lng
              width: 40,
              height: 40,
              child: GestureDetector(
                onTap: () => _mostrarDetalle(props),
                child: Icon(Icons.location_pin, color: Colors.teal, size: 40),
              ),
            );
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
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
              props['categoria'],
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(props['descripcion']),
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
      appBar: AppBar(title: const Text('Mapa de Incidencias Loja')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
              options: MapOptions(
                initialCenter: const LatLng(
                  -4.0085,
                  -79.2239,
                ), // Centro de Loja
                initialZoom: 13.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                ),
                MarkerLayer(markers: _markers),
              ],
            ),
    );
  }
}
