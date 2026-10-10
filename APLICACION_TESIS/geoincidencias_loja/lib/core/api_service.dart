import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';
import '../models/freemium.dart';
import '../models/incidencia.dart';

class ApiService {
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<String?> _getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refresh_token');
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _getToken();
    return {if (token != null) 'Authorization': 'Bearer $token'};
  }

  /// Intenta renovar el access_token usando el refresh_token guardado.
  /// Actualiza SharedPreferences con los tokens nuevos (access y refresh,
  /// ya que ROTATE_REFRESH_TOKENS está activo en el backend).
  /// Devuelve true si logró renovar, false si el refresh también falló.
  Future<bool> _refrescarToken() async {
    final refreshToken = await _getRefreshToken();
    if (refreshToken == null) return false;

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.tokenRefreshUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', data['access']);
        if (data['refresh'] != null) {
          await prefs.setString('refresh_token', data['refresh']);
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Ejecuta una petición y, si responde 401, renueva el token y la repite una vez.
  Future<http.Response> _conReintento(
    Future<http.Response> Function() peticion,
  ) async {
    var response = await peticion();
    if (response.statusCode == 401) {
      final renovado = await _refrescarToken();
      if (renovado) {
        response = await peticion();
      }
    }
    return response;
  }

  /// Envía un nuevo reporte de incidencia (requiere sesión activa).
  /// [anonimo] solo lo acepta el backend para suscriptores VIP (si no, responde 403).
  Future<http.Response> enviarReporte({
    required String categoria,
    required String descripcion,
    required double latitud,
    required double longitud,
    File? foto,
    bool anonimo = false,
  }) async {
    Future<http.Response> hacerPeticion() async {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConstants.reportesUrl),
      );

      final headers = await _authHeaders();
      request.headers.addAll(headers);

      request.fields['categoria'] = categoria;
      request.fields['descripcion'] = descripcion;
      request.fields['latitud'] = latitud.toString();
      request.fields['longitud'] = longitud.toString();
      request.fields['anonimo'] = anonimo ? 'true' : 'false';

      if (foto != null) {
        request.files.add(await http.MultipartFile.fromPath('foto', foto.path));
      }

      var streamedResponse = await request.send();
      return await http.Response.fromStream(streamedResponse);
    }

    var response = await hacerPeticion();

    if (response.statusCode == 401) {
      final renovado = await _refrescarToken();
      if (renovado) {
        response = await hacerPeticion();
      }
    }

    return response;
  }

  /// Obtiene todas las incidencias publicadas (feed público, no requiere login).
  Future<List<dynamic>> obtenerPublicaciones() async {
    final response = await http.get(Uri.parse(ApiConstants.reportesUrl));
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    }
    throw Exception('Error al cargar publicaciones (${response.statusCode})');
  }

  /// Reportes del usuario logueado (requiere filtro ?mios=1 en el backend).
  Future<List<Incidencia>> obtenerMisReportes() async {
    Future<http.Response> hacerPeticion() async {
      final headers = await _authHeaders();
      return http.get(
        Uri.parse('${ApiConstants.reportesUrl}?mios=1'),
        headers: headers,
      );
    }

    var response = await hacerPeticion();

    if (response.statusCode == 401) {
      final renovado = await _refrescarToken();
      if (renovado) {
        response = await hacerPeticion();
      }
    }

    if (response.statusCode == 200) {
      final lista =
          jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      return lista
          .map((e) => Incidencia.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Error al cargar mis reportes (${response.statusCode})');
  }

  /// Línea de tiempo de estados de una incidencia (requiere sesión).
  Future<List<HistorialItem>> obtenerHistorial(int incidenciaId) async {
    Future<http.Response> hacerPeticion() async {
      final headers = await _authHeaders();
      return http.get(
        Uri.parse(ApiConstants.historialUrl(incidenciaId)),
        headers: headers,
      );
    }

    var response = await hacerPeticion();

    if (response.statusCode == 401) {
      final renovado = await _refrescarToken();
      if (renovado) {
        response = await hacerPeticion();
      }
    }

    if (response.statusCode == 200) {
      final lista =
          jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      return lista
          .map((e) => HistorialItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Error al cargar historial (${response.statusCode})');
  }

  /// Obtiene los datos del perfil del usuario logueado.
  Future<Map<String, dynamic>> obtenerPerfil() async {
    Future<http.Response> hacerPeticion() async {
      final headers = await _authHeaders();
      return http.get(Uri.parse(ApiConstants.perfilUrl), headers: headers);
    }

    var response = await hacerPeticion();

    if (response.statusCode == 401) {
      final renovado = await _refrescarToken();
      if (renovado) {
        response = await hacerPeticion();
      }
    }

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    }
    throw Exception('Error al cargar perfil (${response.statusCode})');
  }

  /// Actualiza la foto de perfil del usuario logueado.
  Future<Map<String, dynamic>> actualizarFotoPerfil(File foto) async {
    Future<http.Response> hacerPeticion() async {
      var request = http.MultipartRequest(
        'PATCH',
        Uri.parse(ApiConstants.perfilUrl),
      );
      final headers = await _authHeaders();
      request.headers.addAll(headers);
      request.files.add(
        await http.MultipartFile.fromPath('foto_perfil', foto.path),
      );

      var streamedResponse = await request.send();
      return await http.Response.fromStream(streamedResponse);
    }

    var response = await hacerPeticion();

    if (response.statusCode == 401) {
      final renovado = await _refrescarToken();
      if (renovado) {
        response = await hacerPeticion();
      }
    }

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    }
    throw Exception('Error al actualizar foto (${response.statusCode})');
  }

  // ───────────────────────── Modelo freemium ─────────────────────────

  /// Publicidad del feed. Los suscriptores VIP reciben lista vacía.
  /// Un access_token vencido haría que el backend responda 401 incluso en este
  /// endpoint público: se renueva, y si no se puede, se pide como invitado.
  Future<List<Anuncio>> obtenerAnuncios() async {
    Future<http.Response> conSesion() async {
      final headers = await _authHeaders();
      return http.get(Uri.parse(ApiConstants.anunciosUrl), headers: headers);
    }

    var response = await conSesion();

    if (response.statusCode == 401) {
      final renovado = await _refrescarToken();
      response = renovado
          ? await conSesion()
          : await http.get(Uri.parse(ApiConstants.anunciosUrl));
    }

    if (response.statusCode == 200) {
      final lista =
          jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      return lista
          .map((e) => Anuncio.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Error al cargar anuncios (${response.statusCode})');
  }

  /// Estado de la suscripción y datos del plan.
  Future<Suscripcion> obtenerSuscripcion() async {
    final response = await _conReintento(() async {
      final headers = await _authHeaders();
      return http.get(Uri.parse(ApiConstants.suscripcionUrl), headers: headers);
    });
    if (response.statusCode == 200) {
      return Suscripcion.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
    }
    throw Exception('Error al cargar la suscripción (${response.statusCode})');
  }

  /// Activa o extiende el VIP (pasarela de pago simulada en el backend).
  Future<Suscripcion> activarVip() async {
    final response = await _conReintento(() async {
      final headers = await _authHeaders();
      return http.post(
        Uri.parse(ApiConstants.suscripcionUrl),
        headers: headers,
      );
    });
    if (response.statusCode == 200) {
      return Suscripcion.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
    }
    throw Exception('Error al activar la suscripción (${response.statusCode})');
  }

  /// Cancela el VIP.
  Future<Suscripcion> cancelarVip() async {
    final response = await _conReintento(() async {
      final headers = await _authHeaders();
      return http.delete(
        Uri.parse(ApiConstants.suscripcionUrl),
        headers: headers,
      );
    });
    if (response.statusCode == 200) {
      return Suscripcion.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
    }
    throw Exception(
      'Error al cancelar la suscripción (${response.statusCode})',
    );
  }
}
