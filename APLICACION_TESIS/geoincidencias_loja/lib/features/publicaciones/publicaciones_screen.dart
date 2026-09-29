import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api_service.dart';

class PublicacionesScreen extends StatefulWidget {
  const PublicacionesScreen({super.key});

  @override
  State<PublicacionesScreen> createState() => _PublicacionesScreenState();
}

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

  String _labelCategoria(String categoria) {
    switch (categoria) {
      case 'AGUA':
        return 'Fuga de agua / alcantarillado';
      case 'VIAL':
        return 'Bache / Deterioro vial';
      case 'LUZ':
        return 'Luminaria defectuosa';
      default:
        return 'Otros daños';
    }
  }

  IconData _iconoCategoria(String categoria) {
    switch (categoria) {
      case 'AGUA':
        return Icons.water_drop;
      case 'VIAL':
        return Icons.warning_amber_rounded;
      case 'LUZ':
        return Icons.lightbulb_outline;
      default:
        return Icons.report_problem_outlined;
    }
  }

  Color _colorEstado(String estado) {
    switch (estado.toUpperCase()) {
      case 'RECIBIDO':
        return Colors.teal;
      case 'EN_PROCESO':
        return Colors.orange;
      case 'SOLUCIONADO':
        return Colors.blueGrey;
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
      appBar: AppBar(
        title: const Text('Publicaciones'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 1,
      ),
      body: RefreshIndicator(
        onRefresh: _recargar,
        color: Colors.teal,
        child: FutureBuilder<List<dynamic>>(
          future: _futurePublicaciones,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 100),
                  Icon(Icons.wifi_off, size: 60, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Center(
                    child: Text(
                      'No se pudieron cargar las publicaciones.\nDesliza hacia abajo para reintentar.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            }

            final publicaciones = snapshot.data ?? [];

            if (publicaciones.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 100),
                  Icon(
                    Icons.photo_camera_back_outlined,
                    size: 60,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  const Center(
                    child: Text('Todavía no hay reportes publicados.'),
                  ),
                ],
              );
            }

            return ListView.builder(
              itemCount: publicaciones.length,
              itemBuilder: (context, index) {
                final post = publicaciones[index] as Map<String, dynamic>;
                final String categoria = post['categoria'] ?? 'OTRO';
                final String? descripcion = post['descripcion'];
                final String? fotoUrl = post['foto'];
                final String estado = post['estado'] ?? 'Recibido';
                final String usuarioNombre =
                    post['usuario_nombre'] ?? 'Ciudadano anónimo';
                final String? usuarioFoto = post['usuario_foto'];
                final String fecha = _formatearFecha(post['fecha_creacion']);

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Encabezado: avatar + usuario + fecha ---
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.teal.shade100,
                              backgroundImage: usuarioFoto != null
                                  ? NetworkImage(usuarioFoto)
                                  : null,
                              child: usuarioFoto == null
                                  ? const Icon(Icons.person, color: Colors.teal)
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    usuarioNombre,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
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
                            Chip(
                              avatar: Icon(
                                _iconoCategoria(categoria),
                                size: 16,
                                color: Colors.white,
                              ),
                              label: Text(
                                _labelCategoria(categoria),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                ),
                              ),
                              backgroundColor: Colors.teal.shade400,
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ),

                      // --- Imagen de evidencia ---
                      if (fotoUrl != null)
                        AspectRatio(
                          aspectRatio: 4 / 3,
                          child: Image.network(
                            fotoUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.teal,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  color: Colors.grey.shade200,
                                  child: const Center(
                                    child: Icon(
                                      Icons.broken_image,
                                      size: 40,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                          ),
                        ),

                      // --- Descripción y estado ---
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (descripcion != null && descripcion.isNotEmpty)
                              Text(
                                descripcion,
                                style: const TextStyle(fontSize: 14),
                              ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _colorEstado(
                                      estado,
                                    ).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: _colorEstado(estado),
                                    ),
                                  ),
                                  child: Text(
                                    estado.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _colorEstado(estado),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
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
