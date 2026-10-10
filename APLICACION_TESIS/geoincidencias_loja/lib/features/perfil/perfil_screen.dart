import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_service.dart';
import '../../core/aparecer.dart';
import '../../core/theme.dart';
import '../../models/incidencia.dart';
import '../auth/login_screen.dart';
import '../historial/historial_screen.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();

  Map<String, dynamic>? _perfil;
  bool _cargando = true;
  bool _subiendoFoto = false;
  String? _error;

  /// (etiqueta que manda el backend en reportes_por_estado, valor del estado)
  static const List<(String, String)> _estadosKpi = [
    ('Recibido', 'recibido'),
    ('En revisión', 'en_revision'),
    ('En proceso', 'en_proceso'),
    ('Subsanado', 'subsanado'),
    ('No viable', 'no_viable'),
    ('Cerrado', 'cerrado'),
  ];

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
  }

  Future<void> _cargarPerfil() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final data = await _apiService.obtenerPerfil();
      if (!mounted) return;
      setState(() {
        _perfil = data;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar el perfil';
        _cargando = false;
      });
    }
  }

  Future<void> _cambiarFotoPerfil() async {
    final XFile? imagen = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 800,
    );
    if (imagen == null) return;

    setState(() => _subiendoFoto = true);
    try {
      final data = await _apiService.actualizarFotoPerfil(File(imagen.path));
      if (!mounted) return;
      setState(() {
        _perfil = data;
        _subiendoFoto = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Foto de perfil actualizada'),
          backgroundColor: Colors.teal,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _subiendoFoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ No se pudo actualizar la foto: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _cerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que quieres cerrar tu sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Cerrar sesión',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  String _metodoBiometricoLabel(String? metodo) {
    switch (metodo) {
      case 'facial':
        return 'Reconocimiento facial';
      case 'huella':
        return 'Huella digital';
      default:
        return 'No configurado';
    }
  }

  int _numero(dynamic valor) => (valor as num?)?.toInt() ?? 0;

  String _miembroDesde(String? iso) {
    final fecha = DateTime.tryParse(iso ?? '');
    if (fecha == null) return '-';
    const meses = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    return '${meses[fecha.month - 1]} de ${fecha.year}';
  }

  @override
  Widget build(BuildContext context) {
    final firstName = _perfil?['first_name'] ?? '';
    final lastName = _perfil?['last_name'] ?? '';
    final nombreCompleto = '$firstName $lastName'.trim();
    final nombreMostrar = nombreCompleto.isNotEmpty
        ? nombreCompleto
        : (_perfil?['username'] ?? 'Usuario');

    return Scaffold(
      backgroundColor: AppTheme.fondo,
      // SIN AppBar: el patrón título+subtítulo vive dentro de _cabecera
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 50,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(_error!),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _cargarPerfil,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _cargarPerfil,
              color: AppTheme.primario,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 28),
                children: [
                  Aparecer(child: _cabecera(nombreMostrar.toString())),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Aparecer(
                          orden: 1,
                          child: _tituloSeccion('Mis reportes'),
                        ),
                        const SizedBox(height: 12),
                        _bloqueKpi(),
                        const SizedBox(height: 26),
                        Aparecer(orden: 7, child: _tituloSeccion('Mi cuenta')),
                        const SizedBox(height: 12),
                        Aparecer(orden: 8, child: _tarjetaCuenta()),
                        const SizedBox(height: 24),
                        Aparecer(
                          orden: 9,
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _cerrarSesion,
                              icon: const Icon(
                                Icons.logout,
                                color: Colors.redAccent,
                              ),
                              label: const Text(
                                'Cerrar sesión',
                                style: TextStyle(color: Colors.redAccent),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.redAccent),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _cabecera(String nombre) {
    final fotoUrl = _perfil?['foto_perfil_url'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primarioOscuro, AppTheme.primario],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Mi perfil',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Tu actividad en GeoIncidencias',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Stack(
            children: [
              CircleAvatar(
                radius: 52,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: Colors.teal.shade50,
                  backgroundImage: fotoUrl != null
                      ? NetworkImage(fotoUrl)
                      : null,
                  child: _subiendoFoto
                      ? const CircularProgressIndicator(color: Colors.teal)
                      : (fotoUrl == null
                            ? const Icon(
                                Icons.person,
                                size: 50,
                                color: Colors.teal,
                              )
                            : null),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _subiendoFoto ? null : _cambiarFotoPerfil,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 18,
                      color: AppTheme.primario,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            nombre,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'C.I. ${_perfil?['cedula'] ?? '-'}',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tituloSeccion(String texto) {
    return Text(
      texto,
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: Colors.grey.shade900,
      ),
    );
  }

  Widget _bloqueKpi() {
    final total = _numero(_perfil?['total_reportes']);
    final porEstado = _perfil?['reportes_por_estado'];

    final tarjetaTotal = _KpiCard(
      etiqueta: 'Total',
      orden: 2,
      valor: total,
      color: AppTheme.primario,
      icono: Icons.assignment_outlined,
    );

    if (porEstado is! Map) {
      return Row(children: [Expanded(child: tarjetaTotal)]);
    }

    final tarjetas = <Widget>[];
    for (var i = 0; i < _estadosKpi.length; i++) {
      final (etiqueta, valor) = _estadosKpi[i];
      tarjetas.add(
        _KpiCard(
          etiqueta: etiqueta,
          orden: i + 3 > 6 ? 6 : i + 3,
          valor: _numero(porEstado[etiqueta]),
          color: EstadoHelper.color(valor),
          icono: EstadoHelper.icono(valor),
        ),
      );
    }

    // Resueltos = Subsanado + Cerrado (igual que el panel web).
    final resueltos =
        _numero(porEstado['Subsanado']) + _numero(porEstado['Cerrado']);

    return Column(
      children: [
        tarjetaTotal,
        const SizedBox(height: 12),
        for (var i = 0; i < tarjetas.length; i += 2) ...[
          Row(
            children: [
              Expanded(child: tarjetas[i]),
              const SizedBox(width: 12),
              Expanded(child: tarjetas[i + 1]),
            ],
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 2),
        if (total == 0)
          Text(
            'Todavía no has enviado reportes. Toca Reportar para crear el primero.',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          )
        else ...[
          Aparecer(orden: 6, child: _barraResolucion(total, resueltos)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistorialScreen()),
              ),
              icon: const Icon(Icons.timeline),
              label: const Text('Ver seguimiento de mis reportes'),
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
      ],
    );
  }

  Widget _barraResolucion(int total, int resueltos) {
    final proporcion = total == 0 ? 0.0 : resueltos / total;
    final colorOk = EstadoHelper.color('subsanado');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Reportes resueltos',
                style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
              ),
              Text(
                '${(proporcion * 100).round()} %',
                style: TextStyle(color: colorOk, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: proporcion,
              minHeight: 10,
              backgroundColor: Colors.grey.shade200,
              color: colorOk,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaCuenta() {
    final email = (_perfil?['email'] ?? '').toString();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _filaCuenta(
            Icons.email_outlined,
            'Correo electrónico',
            email.isEmpty ? '-' : email,
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _filaCuenta(
            Icons.fingerprint,
            'Verificación biométrica',
            _metodoBiometricoLabel(_perfil?['metodo_verificacion']),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _filaCuenta(
            Icons.calendar_month_outlined,
            'Miembro desde',
            _miembroDesde(_perfil?['fecha_registro']?.toString()),
          ),
        ],
      ),
    );
  }

  Widget _filaCuenta(IconData icono, String titulo, String valor) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.primario.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icono, color: AppTheme.primario, size: 20),
      ),
      title: Text(
        titulo,
        style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
      ),
      subtitle: Text(
        valor,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade900,
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String etiqueta;
  final int valor;
  final Color color;
  final IconData icono;
  final int orden;

  const _KpiCard({
    required this.etiqueta,
    required this.valor,
    required this.color,
    required this.icono,
    this.orden = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Aparecer(orden: orden, child: _contenido());
  }

  Widget _contenido() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(16),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icono, color: color, size: 18),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              etiqueta,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: valor.toDouble()),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (context, v, _) => Text(
                          v.round().toString(),
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: color,
                            height: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
