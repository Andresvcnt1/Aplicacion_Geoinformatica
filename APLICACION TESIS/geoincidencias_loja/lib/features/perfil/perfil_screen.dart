import 'package:flutter/material.dart';

class PerfilScreen extends StatelessWidget {
  PerfilScreen({super.key});

  // Datos mock temporales (reemplazar con API real después)
  final List<Map<String, String>> _misReportes = [
    {
      'categoria': 'VIAL',
      'descripcion': 'Bache grande en Av. Universitaria',
      'estado': 'RECIBIDO',
      'fecha': '2026-08-11',
    },
    {
      'categoria': 'LUZ',
      'descripcion': 'Luminaria apagada en Parque Jipiro',
      'estado': 'EN_PROCESO',
      'fecha': '2026-08-05',
    },
  ];

  Color _getColorByEstado(String estado) {
    switch (estado) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis Reportes')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _misReportes.length,
        itemBuilder: (ctx, i) {
          final reporte = _misReportes[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _getColorByEstado(reporte['estado']!),
                child: const Icon(Icons.report_problem, color: Colors.white),
              ),
              title: Text(
                reporte['categoria']!,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(reporte['descripcion']!),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Chip(
                    label: Text(
                      reporte['estado']!,
                      style: const TextStyle(fontSize: 10, color: Colors.white),
                    ),
                    backgroundColor: _getColorByEstado(reporte['estado']!),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    reporte['fecha']!,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
