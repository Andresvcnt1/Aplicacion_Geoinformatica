class ApiConstants {
  static const String baseUrl = 'http://192.168.110.13:8000';
  static const String reportesEndpoint = '/api/reportes/';
  static const String loginEndpoint = '/api/login/';
  static const String registroEndpoint = '/api/registro/';
  static const String perfilEndpoint = '/api/perfil/';

  static String get reportesUrl => '$baseUrl$reportesEndpoint';
  static String get loginUrl => '$baseUrl$loginEndpoint';
  static String get registroUrl => '$baseUrl$registroEndpoint';
  static String get perfilUrl => '$baseUrl$perfilEndpoint';
}
