import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../core/config.dart';
import '../models/graffiti.dart';
import 'auth_service.dart';

class ApiService {
  String get _baseUrl => AppConfig.apiBaseUrl;

  Map<String, String> get _headers {
    final token = AuthService.token;
    return {
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Constrói a URL completa para exibir a imagem (ex: http://10.0.2.2:8000/static/uploads/abc.png)
  String getFullMediaUrl(String relativeOrFullUrl) {
    if (relativeOrFullUrl.startsWith('http://') || relativeOrFullUrl.startsWith('https://')) {
      return relativeOrFullUrl;
    }
    final base = AppConfig.serverBaseUrl;
    if (relativeOrFullUrl.startsWith('/')) {
      return '$base$relativeOrFullUrl';
    }
    return '$base/$relativeOrFullUrl';
  }

  /// Consulta os grafites ativos em um raio geográfico
  Future<List<Graffiti>> getNearbyGraffiti({
    required double lat,
    required double lon,
    double radius = 50.0,
  }) async {
    final uri = Uri.parse('$_baseUrl/graffiti/nearby?lat=$lat&lon=$lon&radius=$radius');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) {
        final g = Graffiti.fromJson(item);
        return Graffiti(
          id: g.id,
          userId: g.userId,
          mediaUrl: getFullMediaUrl(g.mediaUrl),
          mediaType: g.mediaType,
          latitude: g.latitude,
          longitude: g.longitude,
          surfaceType: g.surfaceType,
          status: g.status,
          createdAt: g.createdAt,
          protectionUntil: g.protectionUntil,
          expiresAt: g.expiresAt,
          isProtected: g.isProtected,
          distanceMeters: g.distanceMeters,
        );
      }).toList();
    } else {
      throw Exception('Falha ao buscar grafites: ${response.body}');
    }
  }

  /// Reivindica um ponto geográfico e faz upload da mídia
  Future<Graffiti> claimSpot({
    required double lat,
    required double lon,
    required SurfaceType surfaceType,
    required File imageFile,
  }) async {
    await AuthService.ensureAuthenticated();

    final uri = Uri.parse('$_baseUrl/graffiti/claim');
    final request = http.MultipartRequest('POST', uri);

    request.headers.addAll(_headers);
    request.fields['latitude'] = lat.toString();
    request.fields['longitude'] = lon.toString();
    request.fields['surface_type'] = surfaceType.toValue();

    request.files.add(
      await http.MultipartFile.fromPath('file', imageFile.path),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201) {
      final g = Graffiti.fromJson(jsonDecode(response.body));
      return Graffiti(
        id: g.id,
        userId: g.userId,
        mediaUrl: getFullMediaUrl(g.mediaUrl),
        mediaType: g.mediaType,
        latitude: g.latitude,
        longitude: g.longitude,
        surfaceType: g.surfaceType,
        status: g.status,
        createdAt: g.createdAt,
        protectionUntil: g.protectionUntil,
        expiresAt: g.expiresAt,
        isProtected: g.isProtected,
        distanceMeters: g.distanceMeters,
      );
    } else {
      String errorMessage = 'Erro ao fixar arte (${response.statusCode})';
      try {
        final error = jsonDecode(response.body);
        if (error is Map && error['detail'] != null) {
          errorMessage = error['detail'];
        }
      } catch (_) {
        // Fallback para response.body bruto caso não seja JSON
        if (response.body.isNotEmpty) {
          errorMessage = 'Erro (${response.statusCode}): ${response.body}';
        }
      }
      throw Exception(errorMessage);
    }
  }

  /// Denuncia uma arte imprópria
  Future<void> reportGraffiti({required String graffitiId, String? reason}) async {
    await AuthService.ensureAuthenticated();

    final uri = Uri.parse('$_baseUrl/graffiti/$graffitiId/report');
    final response = await http.post(
      uri,
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode({'reason': reason}),
    );

    if (response.statusCode != 200) {
      String errorMessage = 'Erro ao enviar denúncia (${response.statusCode})';
      try {
        final error = jsonDecode(response.body);
        if (error is Map && error['detail'] != null) {
          errorMessage = error['detail'];
        }
      } catch (_) {
        if (response.body.isNotEmpty) {
          errorMessage = 'Erro: ${response.body}';
        }
      }
      throw Exception(errorMessage);
    }
  }
}
