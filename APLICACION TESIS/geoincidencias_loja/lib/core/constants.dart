class ApiConstants {
  static const String baseUrl = 'http://192.168.101.5:8000';
  static const String reportesEndpoint = '/api/reportes/';

  static String get reportesUrl => '$baseUrl$reportesEndpoint';
}
