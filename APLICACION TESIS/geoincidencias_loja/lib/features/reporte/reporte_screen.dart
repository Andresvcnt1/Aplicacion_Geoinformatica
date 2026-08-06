import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
// 👇 IMPORTS CORREGIDOS SEGÚN TU ESTRUCTURA DE CARPETAS
import '../../core/api_service.dart';
import '../auth/biometric_service.dart';
import 'services/geolocator_service.dart';

class ReporteScreen extends StatefulWidget {
  const ReporteScreen({super.key});

  @override
  State<ReporteScreen> createState() => _ReporteScreenState();
}

class _ReporteScreenState extends State<ReporteScreen> {
  final _descripcionController = TextEditingController();
  String _categoriaSeleccionada = 'VIAL';
  String _estadoGps = 'Presiona el botón para obtener la ubicación';
  Position? _posicionActual;
  File? _imagenSeleccionada;
  bool _estaEnviando = false;

  // Instancias de servicios
  final _geolocatorService = GeolocatorService();
  final _apiService = ApiService();
  final _biometricService = BiometricService();
  final ImagePicker _picker = ImagePicker();

  final List<Map<String, String>> _categorias = [
    {'value': 'AGUA', 'label': 'Fuga de Agua / alcantarillado'},
    {'value': 'VIAL', 'label': 'Bache / Deterioro Vial'},
    {'value': 'LUZ', 'label': 'Luminaria Defectuosa'},
    {'value': 'OTRO', 'label': 'Otros daños'},
  ];

  Future<void> _obtenerUbicacionGPS() async {
    setState(() => _estadoGps = 'Obteniendo ubicación...');
    try {
      final position = await _geolocatorService.obtenerUbicacion();
      setState(() {
        _posicionActual = position;
        _estadoGps =
            'Lat: ${position.latitude.toStringAsFixed(6)}\nLng: ${position.longitude.toStringAsFixed(6)}';
      });
    } catch (e) {
      setState(() => _estadoGps = e.toString());
    }
  }

  Future<void> _seleccionarImagen() async {
    final XFile? imagen = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );
    if (imagen != null) {
      setState(() => _imagenSeleccionada = File(imagen.path));
    }
  }

  Future<void> _enviarReporte() async {
    // 1. Validación Biométrica (RF004)
    final bool autenticado = await _biometricService.autenticarUsuario();
    if (!autenticado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Identidad no verificada.')),
      );
      return;
    }

    // 2. Validación GPS
    if (_posicionActual == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, obtén la ubicación primero.')),
      );
      return;
    }

    setState(() => _estaEnviando = true);

    try {
      final response = await _apiService.enviarReporte(
        categoria: _categoriaSeleccionada,
        descripcion: _descripcionController.text,
        latitud: _posicionActual!.latitude,
        longitud: _posicionActual!.longitude,
        foto: _imagenSeleccionada,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Reporte enviado exitosamente.')),
        );
        setState(() {
          _descripcionController.clear();
          _imagenSeleccionada = null;
          _posicionActual = null;
          _estadoGps = 'Presiona el botón para obtener la ubicación';
        });
      } else {
        print('🔴 ERROR BACKEND (${response.statusCode}): ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error servidor: ${response.body}')),
        );
      }
    } catch (e) {
      print('🔴 ERROR CONEXIÓN: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de conexión con el servidor.')),
      );
    } finally {
      setState(() => _estaEnviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reporte Ciudadano Loja')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Seleccione la categoría:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            DropdownButtonFormField<String>(
              value: _categoriaSeleccionada,
              items: _categorias
                  .map(
                    (c) => DropdownMenuItem(
                      value: c['value'],
                      child: Text(c['label']!),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _categoriaSeleccionada = v!),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            const Text(
              'Descripción del Daño:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: _descripcionController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Descripción detallada...',
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Evidencia Visual (Foto):',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _seleccionarImagen,
              child: Container(
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.teal, width: 1.5),
                ),
                child: _imagenSeleccionada != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _imagenSeleccionada!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt, size: 40, color: Colors.teal),
                          Text(
                            'Toca para tomar una foto',
                            style: TextStyle(color: Colors.teal),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              color: Colors.teal.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ubicación GPS:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_estadoGps, textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _obtenerUbicacionGPS,
                      icon: const Icon(Icons.location_on),
                      label: const Text('Obtener Ubicación'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.tealAccent.shade400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _estaEnviando ? null : _enviarReporte,
              child: _estaEnviando
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Enviar Reporte',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
