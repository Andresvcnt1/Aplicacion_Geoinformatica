import 'package:flutter/material.dart';
import '../../core/api_service.dart';
import '../../models/incidencia.dart';
import 'incidencia_detalle_screen.dart';
import 'widgets/reporte_card.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  late Future<List<Incidencia>> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = ApiService().obtenerMisReportes();
  }

  Future<void> _recargar() async {
    setState(() => _futuro = ApiService().obtenerMisReportes());
    await _futuro;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis reportes')),
      body: FutureBuilder<List<Incidencia>>(
        future: _futuro,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No se pudieron cargar tus reportes.'),
                  TextButton(
                    onPressed: _recargar,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }
          final lista = snap.data ?? [];
          if (lista.isEmpty) {
            return const Center(child: Text('Aún no has enviado reportes.'));
          }
          return RefreshIndicator(
            onRefresh: _recargar,
            child: ListView.builder(
              itemCount: lista.length,
              itemBuilder: (_, i) => ReporteCard(
                incidencia: lista[i],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        IncidenciaDetalleScreen(incidencia: lista[i]),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
