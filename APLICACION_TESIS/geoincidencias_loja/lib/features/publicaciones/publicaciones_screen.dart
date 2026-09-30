import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api_service.dart';
import '../../core/aparecer.dart';
import '../../core/theme.dart';

class PublicacionesScreen extends StatefulWidget {
  const PublicacionesScreen({super.key});

  @override
  State<PublicacionesScreen> createState() => _PublicacionesScreenState();
}

class _CategoriaMeta {
  final String etiqueta;
  final IconData icono;
  final Color color;
  const _CategoriaMeta(this.etiqueta, this.icono, this.color);
}

const Map<String, _CategoriaMeta> _categorias = {
  'AGUA': _CategoriaMeta(
    'Agua / alcantarillado',
    Icons.water_drop,
    Color(0xFF0EA5E9),
  ),
  'VIAL': _CategoriaMeta(
    'Bache / deterioro vial',
    Icons.construction,
    Color(0xFF7C3AED),
  ),
  'LUZ': _CategoriaMeta(
    'Luminaria defectuosa',
    Icons.lightbulb,
    Color(0xFFEAB308),
  ),
  'OTRO': _CategoriaMeta(
    'Otros daños',
    Icons.report_problem,
    Color(0xFF64748B),
  ),
};

class _PublicacionesScreenState extends State<PublicacionesScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<dynamic>> _futurePublicaciones;

  @override
  void initState() {
    super.initState();
    _futurePublicaciones = _apiService.obtenerPublicaciones();
  }

  Future<void> _recargar() async {
    setState(() {
      _futurePublicaciones = _apiService.obtenerPublicaciones();
    });
    await _futurePublicaciones;
  }

  _CategoriaMeta _metaCategoria(String categoria) =>
      _categorias[categoria] ?? _categorias['OTRO']!;

  /// Colores reales del estado en el backend: "Recibido", "En proceso",
  /// "Solucionado" (con mayúscula inicial, sin guion bajo).
  Color _colorEstado(String estado) {
    switch (estado.trim().toLowerCase()) {
      case 'recibido':
        return EstadoColors.recibido;
      case 'en proceso':
        return EstadoColors.enProceso;
      case 'solucionado':
        return EstadoColors.solucionado;
      default:
        return Colors.grey;
    }
  }

  String _formatearFecha(String? fechaIso) {
    if (fechaIso == null) return '';
    try {
      final fecha = DateTime.parse(fechaIso).toLocal();
      return DateFormat('dd/MM/yyyy HH:mm').format(fecha);
    } catch (_) {
      return fechaIso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.fondo,
      appBar: AppBar(
        toolbarHeight: 64,
        elevation: 1,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primarioOscuro, AppTheme.primario],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              'Publicaciones',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 2),
            Text(
              'Reportes de la comunidad',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _recargar,
        color: AppTheme.primario,
        child: FutureBuilder<List<dynamic>>(
          future: _futurePublicaciones,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _SkeletonLista();
            }

            if (snapshot.hasError) {
              return _EstadoVacio(
                icono: Icons.wifi_off,
                titulo: 'Sin conexión',
                mensaje:
                    'No se pudieron cargar las publicaciones.\nDesliza hacia abajo o toca el botón para reintentar.',
                esError: true,
                onRetry: () => _recargar(),
              );
            }

            final publicaciones = snapshot.data ?? [];

            if (publicaciones.isEmpty) {
              return const _EstadoVacio(
                icono: Icons.photo_camera_back_outlined,
                titulo: 'Sin reportes aún',
                mensaje: 'Todavía no hay incidencias publicadas en la ciudad.',
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: publicaciones.length,
              itemBuilder: (context, index) {
                final post = publicaciones[index] as Map<String, dynamic>;
                return Aparecer(
                  orden: index > 6 ? 6 : index,
                  child: _PublicacionCard(
                    categoria: post['categoria'] ?? 'OTRO',
                    descripcion: post['descripcion'],
                    fotoUrl: post['foto'],
                    estado: post['estado'] ?? 'Recibido',
                    usuarioNombre:
                        post['usuario_nombre'] ?? 'Ciudadano anónimo',
                    usuarioFoto: post['usuario_foto'],
                    fecha: _formatearFecha(post['fecha_creacion']),
                    metaCategoria: _metaCategoria(post['categoria'] ?? 'OTRO'),
                    colorEstado: _colorEstado(post['estado'] ?? 'Recibido'),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _PublicacionCard extends StatelessWidget {
  final String categoria;
  final String? descripcion;
  final String? fotoUrl;
  final String estado;
  final String usuarioNombre;
  final String? usuarioFoto;
  final String fecha;
  final _CategoriaMeta metaCategoria;
  final Color colorEstado;

  const _PublicacionCard({
    required this.categoria,
    required this.descripcion,
    required this.fotoUrl,
    required this.estado,
    required this.usuarioNombre,
    required this.usuarioFoto,
    required this.fecha,
    required this.metaCategoria,
    required this.colorEstado,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.primario.withValues(alpha: 0.12),
                  backgroundImage: usuarioFoto != null
                      ? NetworkImage(usuarioFoto!)
                      : null,
                  child: usuarioFoto == null
                      ? const Icon(
                          Icons.person,
                          color: AppTheme.primario,
                          size: 20,
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        usuarioNombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      if (fecha.isNotEmpty)
                        Text(
                          fecha,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (fotoUrl != null)
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    fotoUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: Colors.grey.shade100,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.primario,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey.shade100,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.broken_image_outlined,
                              size: 36,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'No se pudo cargar la imagen',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: _Pastilla(
                      icono: metaCategoria.icono,
                      texto: metaCategoria.etiqueta,
                      color: metaCategoria.color,
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 4),
              child: _Pastilla(
                icono: metaCategoria.icono,
                texto: metaCategoria.etiqueta,
                color: metaCategoria.color,
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (descripcion != null && descripcion!.isNotEmpty)
                  Text(
                    descripcion!,
                    style: const TextStyle(fontSize: 14, height: 1.35),
                  ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: colorEstado.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colorEstado.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: colorEstado,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        estado,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: colorEstado,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pastilla extends StatelessWidget {
  final IconData icono;
  final String texto;
  final Color color;

  const _Pastilla({
    required this.icono,
    required this.texto,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            texto,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton (tarjetas fantasma) mientras carga, con un pulso suave de opacidad.
class _SkeletonLista extends StatelessWidget {
  const _SkeletonLista();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 4,
      itemBuilder: (context, index) => const _SkeletonCard(),
    );
  }
}

class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard();

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.45,
        end: 0.9,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 20,
                    backgroundColor: Color(0xFFE2E8F0),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 12,
                          width: 120,
                          color: const Color(0xFFE2E8F0),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 10,
                          width: 80,
                          color: const Color(0xFFEDF2F7),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Container(color: const Color(0xFFE2E8F0)),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 12,
                    width: double.infinity,
                    color: const Color(0xFFEDF2F7),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 12,
                    width: 180,
                    color: const Color(0xFFEDF2F7),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 22,
                    width: 90,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDF2F7),
                      borderRadius: BorderRadius.circular(20),
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
}

class _EstadoVacio extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String mensaje;
  final bool esError;
  final VoidCallback? onRetry;

  const _EstadoVacio({
    required this.icono,
    required this.titulo,
    required this.mensaje,
    this.esError = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final accent = esError ? Colors.red.shade400 : AppTheme.primario;
    return ListView(
      children: [
        const SizedBox(height: 90),
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icono, size: 40, color: accent),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: Text(
            titulo,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Text(
            mensaje,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.45,
            ),
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 20),
          Center(
            child: ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primario,
                foregroundColor: Colors.white,
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
}
