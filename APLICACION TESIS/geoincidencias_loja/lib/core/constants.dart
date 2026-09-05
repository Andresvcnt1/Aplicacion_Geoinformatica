class ApiConstants {
  static const String baseUrl = 'http://143.244.163.81';
  static const String reportesEndpoint = '/api/reportes/';
  static const String loginEndpoint = '/api/login/';
  static const String registroEndpoint = '/api/registro/';
  static const String perfilEndpoint = '/api/perfil/';

  static String get reportesUrl => '$baseUrl$reportesEndpoint';
  static String get loginUrl => '$baseUrl$loginEndpoint';
  static String get registroUrl => '$baseUrl$registroEndpoint';
  static String get perfilUrl => '$baseUrl$perfilEndpoint';
}
