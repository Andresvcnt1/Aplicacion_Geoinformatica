import 'package:flutter/material.dart';

/// Los 6 estados del backend (valores en minúscula, igual que Incidencia.Estado).
enum EstadoIncidencia {
  recibido,
  enRevision,
  enProceso,
  subsanado,
  noViable,
  cerrado,
  desconocido,
}

/// Fuente única de estados en la app (equivalente a estados.ts del panel web).
class EstadoHelper {
  EstadoHelper._();

  static EstadoIncidencia desdeValor(String? valor) {
    switch (valor) {
      case 'recibido':
        return EstadoIncidencia.recibido;
      case 'en_revision':
        return EstadoIncidencia.enRevision;
      case 'en_proceso':
        return EstadoIncidencia.enProceso;
      case 'subsanado':
        return EstadoIncidencia.subsanado;
      case 'no_viable':
        return EstadoIncidencia.noViable;
      case 'cerrado':
        return EstadoIncidencia.cerrado;
      default:
        return EstadoIncidencia.desconocido;
    }
  }

  /// Etiqueta por si el backend no manda estado_display.
  static String etiqueta(String? valor) {
    switch (desdeValor(valor)) {
      case EstadoIncidencia.recibido:
        return 'Recibido';
      case EstadoIncidencia.enRevision:
        return 'En revisión';
      case EstadoIncidencia.enProceso:
        return 'En proceso';
      case EstadoIncidencia.subsanado:
        return 'Subsanado';
      case EstadoIncidencia.noViable:
        return 'No viable';
      case EstadoIncidencia.cerrado:
        return 'Cerrado';
      case EstadoIncidencia.desconocido:
        return valor ?? 'Desconocido';
    }
  }

  /// Ajusta estos colores a los de tu estados.ts para que app y panel coincidan.
  static Color color(String? valor) {
    switch (desdeValor(valor)) {
      case EstadoIncidencia.recibido:
        return const Color(0xFF3B82F6); // azul
      case EstadoIncidencia.enRevision:
        return const Color(0xFF8B5CF6); // violeta
      case EstadoIncidencia.enProceso:
        return const Color(0xFFF59E0B); // ámbar
      case EstadoIncidencia.subsanado:
        return const Color(0xFF10B981); // verde
      case EstadoIncidencia.noViable:
        return const Color(0xFFEF4444); // rojo
      case EstadoIncidencia.cerrado:
        return const Color(0xFF6B7280); // gris
      case EstadoIncidencia.desconocido:
        return const Color(0xFF9CA3AF);
    }
  }

  static IconData icono(String? valor) {
    switch (desdeValor(valor)) {
      case EstadoIncidencia.recibido:
        return Icons.inbox_rounded;
      case EstadoIncidencia.enRevision:
        return Icons.search_rounded;
      case EstadoIncidencia.enProceso:
        return Icons.build_rounded;
      case EstadoIncidencia.subsanado:
        return Icons.check_circle_rounded;
      case EstadoIncidencia.noViable:
        return Icons.cancel_rounded;
      case EstadoIncidencia.cerrado:
        return Icons.lock_rounded;
      case EstadoIncidencia.desconocido:
        return Icons.help_outline_rounded;
    }
  }

  /// Orden de las claves de PerfilSerializer.reportes_por_estado.
  static const List<String> etiquetasPerfil = [
    'Recibido',
    'En revisión',
    'En proceso',
    'Subsanado',
    'No viable',
    'Cerrado',
  ];

  /// Color a partir de la etiqueta del perfil ("En revisión" -> color de en_revision).
  static Color colorDesdeEtiqueta(String etiqueta) {
    const mapa = {
      'Recibido': 'recibido',
      'En revisión': 'en_revision',
      'En proceso': 'en_proceso',
      'Subsanado': 'subsanado',
      'No viable': 'no_viable',
      'Cerrado': 'cerrado',
    };
    return color(mapa[etiqueta]);
  }
}

DateTime? _parseFecha(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

/// Incidencia tal como la devuelve GET /api/reportes/.
class Incidencia {
  final int id;
  final String categoria; // AGUA | VIAL | LUZ | OTRO
  final String descripcion;
  final String? fotoUrl;
  final DateTime? fechaCreacion;
  final String estado; // valor en minúscula: recibido, en_revision, ...
  final String estadoDisplay;
  final dynamic ubicacion; // se deja dynamic hasta ver cómo la usa tu UI
  final String? usuarioNombre;
  final String? usuarioFoto;

  const Incidencia({
    required this.id,
    required this.categoria,
    required this.descripcion,
    required this.estado,
    required this.estadoDisplay,
    this.fotoUrl,
    this.fechaCreacion,
    this.ubicacion,
    this.usuarioNombre,
    this.usuarioFoto,
  });

  factory Incidencia.fromJson(Map<String, dynamic> json) {
    final estado = (json['estado'] ?? '').toString();
    return Incidencia(
      id: json['id'] as int,
      categoria: (json['categoria'] ?? 'OTRO').toString(),
      descripcion: (json['descripcion'] ?? '').toString(),
      fotoUrl: json['foto'] as String?,
      fechaCreacion: _parseFecha(json['fecha_creacion']),
      estado: estado,
      estadoDisplay: (json['estado_display'] ?? EstadoHelper.etiqueta(estado))
          .toString(),
      ubicacion: json['ubicacion'],
      usuarioNombre: json['usuario_nombre'] as String?,
      usuarioFoto: json['usuario_foto'] as String?,
    );
  }

  Color get colorEstado => EstadoHelper.color(estado);
  IconData get iconoEstado => EstadoHelper.icono(estado);
}

/// Un cambio de estado de GET /api/incidencias/<id>/historial/.
class HistorialItem {
  final int id;
  final String? estadoAnterior; // null en el primer registro
  final String estadoNuevo;
  final String estadoNuevoDisplay;
  final DateTime? fechaCambio;
  final String observacion;
  final String? responsable; // null si quien consulta no es staff

  const HistorialItem({
    required this.id,
    required this.estadoNuevo,
    required this.estadoNuevoDisplay,
    this.estadoAnterior,
    this.fechaCambio,
    this.observacion = '',
    this.responsable,
  });

  factory HistorialItem.fromJson(Map<String, dynamic> json) {
    final nuevo = (json['estado_nuevo'] ?? '').toString();
    final anterior = json['estado_anterior'];
    return HistorialItem(
      id: json['id'] as int,
      estadoAnterior: (anterior == null || anterior.toString().isEmpty)
          ? null
          : anterior.toString(),
      estadoNuevo: nuevo,
      estadoNuevoDisplay:
          (json['estado_nuevo_display'] ?? EstadoHelper.etiqueta(nuevo))
              .toString(),
      fechaCambio: _parseFecha(json['fecha_cambio']),
      observacion: (json['observacion'] ?? '').toString(),
      responsable: json['responsable'] as String?,
    );
  }

  Color get color => EstadoHelper.color(estadoNuevo);
  IconData get icono => EstadoHelper.icono(estadoNuevo);
}
