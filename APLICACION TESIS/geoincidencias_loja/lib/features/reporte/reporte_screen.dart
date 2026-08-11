import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api_service.dart';
import '../auth/biometric_service.dart';
import 'services/geolocator_service.dart';

class ReporteScreen extends StatefulWidget {
  const ReporteScreen({super.key});

  @override
  State<ReporteScreen> createState() => _ReporteScreenState();
}

class _ReporteScreenState extends State<ReporteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descripcionController = TextEditingController();

  String _categoriaSeleccionada = 'VIAL';
  String _estadoGps = 'Presiona el botón para obtener la ubicación';
  Position? _posicionActual;
  File? _imagenSeleccionada;

  bool _estaEnviando = false;
  bool _cargandoGps = false;
  bool _cargandoFoto = false;

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

  // --- Helpers Responsivos Locales ---
  double _getResponsiveHeight(BuildContext context, double percentage) {
    return MediaQuery.of(context).size.height * percentage;
  }

  double _getResponsiveFontSize(BuildContext context, double baseSize) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return baseSize * 0.85;
    if (width > 600) return baseSize * 1.2;
    return baseSize;
  }

  EdgeInsets _getResponsivePadding(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    return EdgeInsets.all(isTablet ? 24.0 : 16.0);
  }

  Future<void> _obtenerUbicacionGPS() async {
    setState(() {
      _cargandoGps = true;
      _estadoGps = 'Obteniendo ubicación satelital...';
    });
    try {
      final position = await _geolocatorService.obtenerUbicacion();
      if (!mounted) return;
      setState(() {
        _posicionActual = position;
        _estadoGps =
            '✅ Ubicación obtenida\nLat: ${position.latitude.toStringAsFixed(6)}\nLng: ${position.longitude.toStringAsFixed(6)}';
        _cargandoGps = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _estadoGps = '❌ Error: $e';
        _cargandoGps = false;
      });
    }
  }

  Future<void> _seleccionarImagen() async {
    setState(() => _cargandoFoto = true);
    try {
      final XFile? imagen = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );
      if (imagen != null && mounted)
        setState(() => _imagenSeleccionada = File(imagen.path));
    } finally {
      if (mounted) setState(() => _cargandoFoto = false);
    }
  }

  Future<void> _enviarReporte() async {
    if (!_formKey.currentState!.validate()) return;
    final bool autenticado = await _biometricService.autenticarUsuario();
    if (!autenticado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(' Identidad no verificada.')),
      );
      return;
    }
    setState(() => _estaEnviando = true);
    try {
      final response = await _apiService.enviarReporte(
        categoria: _categoriaSeleccionada,
        descripcion: _descripcionController.text.trim(),
        latitud: _posicionActual!.latitude,
        longitud: _posicionActual!.longitude,
        foto: _imagenSeleccionada,
      );
      if (!mounted) return;
      if (response.statusCode == 201 || response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('✅ Reporte enviado exitosamente'),
              ],
            ),
            backgroundColor: Colors.teal,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _formKey.currentState!.reset();
        setState(() {
          _descripcionController.clear();
          _imagenSeleccionada = null;
          _posicionActual = null;
          _categoriaSeleccionada = 'VIAL';
          _estadoGps = 'Presiona el botón para obtener la ubicación';
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error servidor (${response.statusCode})'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de conexión: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _estaEnviando = false);
    }
  }

  @override
  void dispose() {
    _descripcionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🔑 CLAVE RESPONSIVO: Ajuste automático al teclado virtual
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Reporte Ciudadano Loja'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: _getResponsivePadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Categoría ---
              Text(
                'Seleccione la categoría:',
                style: TextStyle(
                  fontSize: _getResponsiveFontSize(context, 16),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
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
                validator: (value) =>
                    value == null ? 'Seleccione una categoría' : null,
              ),
              const SizedBox(height: 20),

              // --- Descripción ---
              Text(
                'Descripción del Daño:',
                style: TextStyle(
                  fontSize: _getResponsiveFontSize(context, 16),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descripcionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Describa el daño con detalle...',
                  helperText: 'Mínimo 10 caracteres',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty)
                    return 'La descripción es obligatoria';
                  if (value.trim().length < 10) return 'Mínimo 10 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // --- Foto Responsiva (AspectRatio) ---
              Text(
                'Evidencia Visual (Foto):',
                style: TextStyle(
                  fontSize: _getResponsiveFontSize(context, 16),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              AspectRatio(
                // 🔑 Mantiene proporción 4:3 en cualquier pantalla
                aspectRatio: 4 / 3,
                child: GestureDetector(
                  onTap: _cargandoFoto ? null : _seleccionarImagen,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _imagenSeleccionada != null
                            ? Colors.teal
                            : Colors.grey.shade400,
                        width: _imagenSeleccionada != null ? 2 : 1.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _cargandoFoto
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Colors.teal,
                              ),
                            )
                          : _imagenSeleccionada != null
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(
                                  _imagenSeleccionada!,
                                  fit: BoxFit.cover,
                                ),
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Icon(
                                      Icons.check_circle,
                                      color: Colors.greenAccent,
                                      size: 24,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 12,
                                  right: 12,
                                  child: InkWell(
                                    onTap: _seleccionarImagen,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.camera_alt_outlined,
                                  size: 48,
                                  color: Colors.teal,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Toca para tomar foto',
                                  style: TextStyle(color: Colors.teal),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // --- GPS Responsivo ---
              Card(
                elevation: _posicionActual != null ? 4 : 0,
                color: _posicionActual != null
                    ? Colors.teal.shade50
                    : Colors.grey.shade100,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: _posicionActual != null
                        ? Colors.teal
                        : Colors.grey.shade300,
                    width: _posicionActual != null ? 2 : 1,
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(
                    MediaQuery.of(context).size.width > 600 ? 20.0 : 16.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _posicionActual != null
                                ? Icons.check_circle
                                : Icons.location_off,
                            color: _posicionActual != null
                                ? Colors.teal
                                : Colors.redAccent,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Ubicación GPS',
                            style: TextStyle(
                              fontSize: _getResponsiveFontSize(context, 16),
                              fontWeight: FontWeight.bold,
                              color: _posicionActual != null
                                  ? Colors.teal
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _estadoGps,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _posicionActual != null
                              ? Colors.black87
                              : Colors.grey.shade600,
                          fontSize: _getResponsiveFontSize(context, 14),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _cargandoGps ? null : _obtenerUbicacionGPS,
                          icon: _cargandoGps
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.my_location, size: 18),
                          label: Text(
                            _cargandoGps
                                ? 'Buscando señal...'
                                : 'Obtener Ubicación Actual',
                            style: TextStyle(
                              fontSize: _getResponsiveFontSize(context, 14),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // --- Botón Enviar ---
              SizedBox(
                height: _getResponsiveHeight(
                  context,
                  0.06,
                ), // 6% de la altura de pantalla
                child: ElevatedButton(
                  onPressed: _estaEnviando ? null : _enviarReporte,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _estaEnviando
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
                            Text(
                              'Enviando reporte...',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          'ENVIAR REPORTE CIUDADANO',
                          style: TextStyle(
                            fontSize: _getResponsiveFontSize(context, 16),
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),

              //  ESPACIO PARA EL TECLADO VIRTUAL
              SizedBox(height: bottomInset + 20),
            ],
          ),
        ),
      ),
    );
  }
}
