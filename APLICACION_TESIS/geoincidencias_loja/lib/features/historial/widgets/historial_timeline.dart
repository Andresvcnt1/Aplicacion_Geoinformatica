import 'package:flutter/material.dart';
import '../../../models/incidencia.dart';

String formatearFecha(DateTime? f) {
  if (f == null) return '';
  const meses = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  final hh = f.hour.toString().padLeft(2, '0');
  final mm = f.minute.toString().padLeft(2, '0');
  return '${f.day} ${meses[f.month - 1]} ${f.year}, $hh:$mm';
}

/// Línea de tiempo vertical de cambios de estado (HU004).
class HistorialTimeline extends StatelessWidget {
  final List<HistorialItem> items;
  const HistorialTimeline({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Aún no hay cambios de estado registrados.'),
      );
    }

    return Column(
      children: List.generate(items.length, (i) {
        final item = items[i];
        final esUltimo = i == items.length - 1;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 40,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: item.color,
                      child: Icon(item.icono, size: 16, color: Colors.white),
                    ),
                    if (!esUltimo)
                      Expanded(
                        child: Container(width: 2, color: Colors.grey.shade300),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: esUltimo ? 0 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.estadoNuevoDisplay,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: item.color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatearFecha(item.fechaCambio),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (item.observacion.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(item.observacion),
                      ],
                      if (item.responsable != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Responsable: ${item.responsable}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
