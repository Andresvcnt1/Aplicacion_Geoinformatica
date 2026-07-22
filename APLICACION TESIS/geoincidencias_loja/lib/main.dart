import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const GeoIncidenciasApp());
}

class GeoIncidenciasApp extends StatelessWidget {
  const GeoIncidenciasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeoIncidencias Loja',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const FormularioReporteScreen(),
    );
  }
}

class FormularioReporteScreen extends StatefulWidget {
  const FormularioReporteScreen({super.key});

  @override
  State<FormularioReporteScreen> createState() =>
      _FormularioReporteScreenState();
}

class _FormularioReporteScreenState extends State<FormularioReporteScreen> {
  final _descripcionController = TextEditingController();
  String _categoriaSeleccionada = 'VIAL';
  String _estadoGps = 'Presiona el botón para obtener la ubicación';
  Position? _posicionActual;

  // Variables para la imagen
  File? _imagenSeleccionada;
  final ImagePicker _picker = ImagePicker();
  bool _estaEnviando = false;

  final List<Map<String, String>> _categorias = [
    {'value': 'AGUA', 'label': 'Fuga de Agua / alcantarillado'},
    {'value': 'VIAL', 'label': 'Bache / Deterioro Vial'},
    {'value': 'LUZ', 'label': 'Luminaria Defectuosa'},
    {'value': 'OTRO', 'label': 'Otros daños'},
  ];

  Future<void> _obtenerUbicacionGPS() async {
    // ... (Tu lógica de GPS se mantiene exactamente igual, no la modificamos aquí por brevedad)
    bool servicioHabilitado = await Geolocator.isLocationServiceEnabled();
    if (!servicioHabilitado) {
      setState(
        () => _estadoGps = 'El servicio de ubicación está deshabilitado.',
      );
      return;
    }
    LocationPermission permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
      if (permiso == LocationPermission.denied) {
        setState(() => _estadoGps = 'Permiso de ubicación denegado.');
        return;
      }
    }
    setState(() => _estadoGps = 'Obteniendo ubicación...');
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    setState(() {
      _posicionActual = position;
      _estadoGps =
          'Latitud: ${position.latitude.toStringAsFixed(6)}\nLng: ${position.longitude.toStringAsFixed(6)}';
    });
  }

  Future<void> _seleccionarImagen() async {
    final XFile? imagen = await _picker.pickImage(
      source: ImageSource
          .camera, // Puedes cambiar a ImageSource.gallery si prefieres galería
      imageQuality:
          70, // Comprime un poco la imagen para que la subida sea más rápida
    );
    if (imagen != null) {
      setState(() {
        _imagenSeleccionada = File(imagen.path);
      });
    }
  }

  Future<void> _enviarReporteAlBackend() async {
    if (_posicionActual == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, obtén la ubicación antes de enviar.'),
        ),
      );
      return;
    }

    setState(() => _estaEnviando = true);

    try {
      var uri = Uri.parse('http://192.168.101.5:8888/api/reportes/');
      var request = http.MultipartRequest('POST', uri);

      // 1. Campos de texto normales
      request.fields['categoria'] = _categoriaSeleccionada;
      request.fields['descripcion'] = _descripcionController.text;

      // 2. Coordenadas como texto (El serializer de Django las convertirá a Point)
      request.fields['latitud'] = _posicionActual!.latitude.toString();
      request.fields['longitud'] = _posicionActual!.longitude.toString();

      // 3. Adjuntar la imagen si existe
      if (_imagenSeleccionada != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'foto', // ⚠️ ESTE NOMBRE DEBE SER IDÉNTICO al campo ImageField en tu models.py
            _imagenSeleccionada!.path,
          ),
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201 || response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Reporte enviado exitosamente con foto.'),
          ),
        );
        // Limpiar formulario
        setState(() {
          _descripcionController.clear();
          _imagenSeleccionada = null;
          _posicionActual = null;
          _estadoGps = 'Presiona el botón para obtener la ubicación';
        });
      } else {
        print(
          '🔴 ERROR DEL BACKEND (Status ${response.statusCode}): ${response.body}',
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${response.body}')));
      }
    } catch (e) {
      print('🔴 ERROR DE CONEXIÓN: $e');
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
      appBar: AppBar(
        title: const Text('Reporte Ciudadano Loja'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Categoría ---
            const Text(
              'Seleccione la categoría:',
              style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
            ),
            DropdownButtonFormField<String>(
              value: _categoriaSeleccionada,
              items: _categorias.map((categoria) {
                return DropdownMenuItem<String>(
                  value: categoria['value'],
                  child: Text(categoria['label']!),
                );
              }).toList(),
              onChanged: (String? newValue) =>
                  setState(() => _categoriaSeleccionada = newValue!),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),

            // --- Descripción ---
            const Text(
              'Descripción del Daño:',
              style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
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

            // --- Foto (NUEVO) ---
            const Text(
              'Evidencia Visual (Foto):',
              style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
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
                          SizedBox(height: 8),
                          Text(
                            'Toca para tomar una foto',
                            style: TextStyle(color: Colors.teal),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // --- GPS ---
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
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _estadoGps,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black87),
                    ),
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

            // --- Botón Enviar ---
            ElevatedButton(
              onPressed: _estaEnviando ? null : _enviarReporteAlBackend,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
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
