import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

class ApiService {
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _getToken();
    return {if (token != null) 'Authorization': 'Bearer $token'};
  }

  /// Envía un nuevo reporte de incidencia (requiere sesión activa).
  Future<http.Response> enviarReporte({
    required String categoria,
    required String descripcion,
    required double latitud,
    required double longitud,
    File? foto,
  }) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse(ApiConstants.reportesUrl),
    );

    final token = await _getToken();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.fields['categoria'] = categoria;
    request.fields['descripcion'] = descripcion;
    request.fields['latitud'] = latitud.toString();
    request.fields['longitud'] = longitud.toString();

    if (foto != null) {
      request.files.add(await http.MultipartFile.fromPath('foto', foto.path));
    }

    var streamedResponse = await request.send();
    return await http.Response.fromStream(streamedResponse);
  }

  /// Obtiene todas las incidencias publicadas (feed público, no requiere login).
  Future<List<dynamic>> obtenerPublicaciones() async {
    final response = await http.get(Uri.parse(ApiConstants.reportesUrl));
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    }
    throw Exception('Error al cargar publicaciones (${response.statusCode})');
  }

  /// Obtiene los datos del perfil del usuario logueado.
  Future<Map<String, dynamic>> obtenerPerfil() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse(ApiConstants.perfilUrl),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    }
    throw Exception('Error al cargar perfil (${response.statusCode})');
  }

  /// Actualiza la foto de perfil del usuario logueado.
  Future<Map<String, dynamic>> actualizarFotoPerfil(File foto) async {
    final token = await _getToken();
    var request = http.MultipartRequest(
      'PATCH',
      Uri.parse(ApiConstants.perfilUrl),
    );
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.files.add(
      await http.MultipartFile.fromPath('foto_perfil', foto.path),
    );

    var streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    }
    throw Exception('Error al actualizar foto (${response.statusCode})');
  }
}
