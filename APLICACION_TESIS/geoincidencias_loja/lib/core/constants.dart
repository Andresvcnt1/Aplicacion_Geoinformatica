class ApiConstants {
  static const String baseUrl = 'https://geoincidenciasloja.duckdns.org';
  static const String reportesEndpoint = '/api/reportes/';
  static const String loginEndpoint = '/api/login/';
  static const String registroEndpoint = '/api/registro/';
  static const String perfilEndpoint = '/api/perfil/';
  static String get reportesUrl => '$baseUrl$reportesEndpoint';
  static String get loginUrl => '$baseUrl$loginEndpoint';
  static String get registroUrl => '$baseUrl$registroEndpoint';
  static String get perfilUrl => '$baseUrl$perfilEndpoint';
  static String get tokenRefreshUrl => '$baseUrl/api/token/refresh/';

  /// Modelo freemium: suscripción VIP y publicidad.
  static String get suscripcionUrl => '$baseUrl/api/suscripcion/';
  static String get anunciosUrl => '$baseUrl/api/anuncios/';

  /// Historial de estados de una incidencia (requiere sesión).
  static String historialUrl(int incidenciaId) =>
      '$baseUrl/api/incidencias/$incidenciaId/historial/';
}
