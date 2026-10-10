import 'package:flutter/material.dart';
import '../../core/api_service.dart';
import '../../models/incidencia.dart';
import 'widgets/historial_timeline.dart';

class IncidenciaDetalleScreen extends StatefulWidget {
  final Incidencia incidencia;
  const IncidenciaDetalleScreen({super.key, required this.incidencia});

  @override
  State<IncidenciaDetalleScreen> createState() =>
      _IncidenciaDetalleScreenState();
}

class _IncidenciaDetalleScreenState extends State<IncidenciaDetalleScreen> {
  late Future<List<HistorialItem>> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = ApiService().obtenerHistorial(widget.incidencia.id);
  }

  @override
  Widget build(BuildContext context) {
    final inc = widget.incidencia;
    return Scaffold(
      appBar: AppBar(title: Text('Incidencia #${inc.id}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (inc.fotoUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                inc.fotoUrl!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            inc.categoria,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(inc.descripcion),
          const SizedBox(height: 4),
          Text(
            formatearFecha(inc.fechaCreacion),
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const Divider(height: 32),
          const Text(
            'Seguimiento',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<HistorialItem>>(
            future: _futuro,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Column(
                  children: [
                    const Text('No se pudo cargar el seguimiento.'),
                    TextButton(
                      onPressed: () => setState(() {
                        _futuro = ApiService().obtenerHistorial(inc.id);
                      }),
                      child: const Text('Reintentar'),
                    ),
                  ],
                );
              }
              return HistorialTimeline(items: snap.data ?? []);
            },
          ),
        ],
      ),
    );
  }
}
