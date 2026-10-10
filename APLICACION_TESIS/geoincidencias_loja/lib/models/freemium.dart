/// Modelos del modelo freemium: publicidad y suscripción VIP.

DateTime? _fecha(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

/// GET /api/anuncios/
class Anuncio {
  final int id;
  final String anunciante;
  final String titulo;
  final String texto;
  final String? imagenUrl;
  final String? enlace;

  const Anuncio({
    required this.id,
    required this.anunciante,
    required this.titulo,
    this.texto = '',
    this.imagenUrl,
    this.enlace,
  });

  factory Anuncio.fromJson(Map<String, dynamic> json) {
    final enlace = (json['enlace'] ?? '').toString().trim();
    return Anuncio(
      id: json['id'] as int,
      anunciante: (json['anunciante'] ?? '').toString(),
      titulo: (json['titulo'] ?? '').toString(),
      texto: (json['texto'] ?? '').toString(),
      imagenUrl: json['imagen'] as String?,
      enlace: enlace.isEmpty ? null : enlace,
    );
  }
}

/// Plan único del backend (campo "plan" de /api/suscripcion/).
class PlanVip {
  final String nombre;
  final int dias;
  final String precioUsd;
  final List<String> beneficios;

  const PlanVip({
    required this.nombre,
    required this.dias,
    required this.precioUsd,
    required this.beneficios,
  });

  factory PlanVip.fromJson(Map<String, dynamic> json) => PlanVip(
    nombre: (json['nombre'] ?? 'VIP').toString(),
    dias: (json['dias'] as num?)?.toInt() ?? 30,
    precioUsd: (json['precio_usd'] ?? '').toString(),
    beneficios: (json['beneficios'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList(),
  );
}

/// Respuesta de GET / POST / DELETE /api/suscripcion/.
class Suscripcion {
  final bool esVip;
  final DateTime? vipHasta;
  final PlanVip plan;

  /// true mientras la pasarela de pago sea una simulación (sin cobro real).
  final bool simulado;

  const Suscripcion({
    required this.esVip,
    required this.plan,
    this.vipHasta,
    this.simulado = true,
  });

  factory Suscripcion.fromJson(Map<String, dynamic> json) => Suscripcion(
    esVip: json['es_vip'] == true,
    vipHasta: _fecha(json['vip_hasta']),
    plan: PlanVip.fromJson((json['plan'] as Map<String, dynamic>?) ?? {}),
    simulado: json['simulado'] != false,
  );
}
