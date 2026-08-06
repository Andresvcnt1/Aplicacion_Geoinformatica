import 'dart:io';
import 'package:http/http.dart' as http;
import 'constants.dart'; // Importa desde la misma carpeta core

class ApiService {
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
}
