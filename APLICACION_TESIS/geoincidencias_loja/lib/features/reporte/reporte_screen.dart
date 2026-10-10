import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api_service.dart';
import '../../core/aparecer.dart';
import '../../core/app_header.dart';
import '../../core/theme.dart';
import '../auth/biometric_service.dart';
import '../suscripcion/suscripcion_screen.dart';
import 'services/geolocator_service.dart';
import 'widgets/categoria_dropdown.dart';
import 'widgets/foto_picker.dart';
import 'widgets/gps_card.dart';

class ReporteScreen extends StatefulWidget {
  const ReporteScreen({super.key});

  @override
  State<ReporteScreen> createState() => _ReporteScreenState();
}

class _ReporteScreenState extends State<ReporteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descripcionController = TextEditingController();

  String _categoriaSeleccionada = 'VIAL';
  Position? _posicionActual;
  bool _errorGps = false;
  String? _mensajeErrorGps;
  File? _imagenSeleccionada;
  bool _fotoObligatoriaResaltada = false;

  bool _estaEnviando = false;
  bool _cargandoGps = false;
  bool _cargandoFoto = false;

  // Modelo freemium
  bool _esVip = false;
  bool _anonimo = false;

  final _geolocatorService = GeolocatorService();
  final _apiService = ApiService();
  final _biometricService = BiometricService();
  final ImagePicker _picker = ImagePicker();

  static const List<CategoriaOpcion> _categorias = [
    CategoriaOpcion(
      'AGUA',
      'Fuga de agua / alcantarillado',
      Icons.water_drop_outlined,
    ),
    CategoriaOpcion(
      'VIAL',
      'Bache / deterioro vial',
      Icons.construction_outlined,
    ),
    CategoriaOpcion('LUZ', 'Luminaria defectuosa', Icons.lightbulb_outline),
    CategoriaOpcion('OTRO', 'Otros daños', Icons.report_problem_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _cargarEsVip();
  }

  double _getResponsiveHeight(BuildContext context, double percentage) {
    return MediaQuery.of(context).size.height * percentage;
  }

  EdgeInsets _getResponsivePadding(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    return EdgeInsets.all(isTablet ? 24.0 : 16.0);
  }

  Future<void> _obtenerUbicacionGPS() async {
    setState(() {
      _cargandoGps = true;
      _errorGps = false;
      _mensajeErrorGps = null;
    });
    try {
      final position = await _geolocatorService.obtenerUbicacion();
      if (!mounted) return;
      setState(() {
        _posicionActual = position;
        _cargandoGps = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _posicionActual = null;
        _errorGps = true;
        _mensajeErrorGps = e.toString().replaceFirst('Exception: ', '');
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
      if (imagen != null && mounted) {
        setState(() {
          _imagenSeleccionada = File(imagen.path);
          _fotoObligatoriaResaltada = false;
        });
      }
    } finally {
      if (mounted) setState(() => _cargandoFoto = false);
    }
  }

  // ───────────────────────── Modelo freemium ─────────────────────────

  Future<void> _cargarEsVip() async {
    try {
      final perfil = await _apiService.obtenerPerfil();
      if (!mounted) return;
      setState(() {
        _esVip = perfil['es_vip'] == true;
        if (!_esVip) _anonimo = false;
      });
    } catch (_) {
      // Si falla, se asume plan gratuito
    }
  }

  Future<void> _abrirSuscripcion() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SuscripcionScreen()),
    );
    if (!mounted) return;
    await _cargarEsVip();
  }

  void _alternarAnonimo(bool valor) {
    if (!_esVip) {
      _abrirSuscripcion();
      return;
    }
    setState(() => _anonimo = valor);
  }

  Widget _tarjetaAnonimo() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: _estaEnviando ? null : () => _alternarAnonimo(!_anonimo),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primario.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.visibility_off_outlined,
            color: AppTheme.primario,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            const Flexible(
              child: Text(
                'Reporte anónimo',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'VIP',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          _esVip
              ? 'Tu nombre y foto no se mostrarán al público. Tu reporte se atiende con prioridad.'
              : 'Función exclusiva para suscriptores VIP. Toca para ver el plan.',
          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
        ),
        trailing: Switch(
          value: _anonimo,
          onChanged: _estaEnviando ? null : _alternarAnonimo,
        ),
      ),
    );
  }

  // ───────────────────────── Envío del reporte ─────────────────────────

  Future<void> _enviarReporte() async {
    if (!_formKey.currentState!.validate()) return;

    if (_imagenSeleccionada == null) {
      setState(() => _fotoObligatoriaResaltada = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Debes tomar una foto como evidencia.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_posicionActual == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Obtén tu ubicación GPS antes de enviar.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final bool autenticado = await _biometricService.autenticarUsuario();
    if (!autenticado) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Identidad no verificada.')),
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
        anonimo: _anonimo,
      );

      if (!mounted) return;

      if (response.statusCode == 201 || response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
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
          _errorGps = false;
          _mensajeErrorGps = null;
          _categoriaSeleccionada = 'VIAL';
          _fotoObligatoriaResaltada = false;
          _anonimo = false;
        });
      } else {
        String mensajeError = 'Error del servidor (${response.statusCode})';
        if (response.statusCode == 400) {
          mensajeError =
              '⚠️ No se pudo enviar. Verifica que:\n1. La foto esté adjunta\n2. Estés dentro del área municipal';
        } else if (response.statusCode == 403) {
          mensajeError =
              '⭐ El reporte anónimo es exclusivo para suscriptores VIP.';
          _cargarEsVip();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeError),
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: AppTheme.fondo,
      resizeToAvoidBottomInset: true,
      appBar: const AppHeader(
        titulo: 'Reportar incidencia',
        subtitulo: 'Reporta en menos de un minuto',
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: _getResponsivePadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Aparecer(
                orden: 0,
                child: _seccion(
                  titulo: 'Selecciona la categoría',
                  hijo: CategoriaSelector(
                    opciones: _categorias,
                    seleccionada: _categoriaSeleccionada,
                    onChanged: (v) =>
                        setState(() => _categoriaSeleccionada = v),
                  ),
                ),
              ),
              const SizedBox(height: 22),

              Aparecer(
                orden: 1,
                child: _seccion(
                  titulo: 'Describe el daño',
                  hijo: TextFormField(
                    controller: _descripcionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      hintText: 'Describe el daño con detalle...',
                      helperText: 'Mínimo 10 caracteres',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'La descripción es obligatoria';
                      }
                      if (value.trim().length < 10) {
                        return 'Mínimo 10 caracteres';
                      }
                      return null;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 22),

              Aparecer(
                orden: 2,
                child: _seccion(
                  titulo: 'Evidencia fotográfica',
                  hijo: FotoPicker(
                    imagen: _imagenSeleccionada,
                    cargando: _cargandoFoto,
                    resaltarFalta: _fotoObligatoriaResaltada,
                    onTap: _seleccionarImagen,
                  ),
                ),
              ),
              const SizedBox(height: 22),

              Aparecer(
                orden: 3,
                child: GpsCard(
                  cargando: _cargandoGps,
                  posicion: _posicionActual,
                  tieneError: _errorGps,
                  mensajeError: _mensajeErrorGps,
                  onTap: _obtenerUbicacionGPS,
                ),
              ),
              const SizedBox(height: 22),

              Aparecer(orden: 4, child: _tarjetaAnonimo()),
              const SizedBox(height: 28),

              Aparecer(
                orden: 5,
                child: SizedBox(
                  height: _getResponsiveHeight(context, 0.06),
                  child: ElevatedButton(
                    onPressed: _estaEnviando ? null : _enviarReporte,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primario,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _estaEnviando
                          ? const Row(
                              key: ValueKey('enviando'),
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
                          : const Text(
                              'ENVIAR REPORTE',
                              key: ValueKey('idle'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: bottomInset + 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _seccion({required String titulo, required Widget hijo}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade900,
          ),
        ),
        const SizedBox(height: 10),
        hijo,
      ],
    );
  }
}
