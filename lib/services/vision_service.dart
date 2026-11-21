import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:whatcanicook/core/config.dart';
import 'package:whatcanicook/core/result.dart';
import 'package:whatcanicook/models/ingredient.dart';

class VisionAnalysis {
  const VisionAnalysis({
    required this.ingredients,
    required this.model,
    this.warning,
  });

  final List<DetectedIngredient> ingredients;
  final String model;
  final String? warning;
}

/// Cliente del backend seguro de WHATCANICOOK.
///
/// La app nunca contiene la clave de Gemini: envía la imagen al backend y
/// recibe únicamente la lista de ingredientes detectados.
class VisionService {
  VisionService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? AppConfig.visionBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  bool get isConfigured => _baseUrl.isNotEmpty;

  Future<AppResult<VisionAnalysis>> analyze(File image) async {
    if (!isConfigured) {
      return const AppFailure(
        'El análisis con IA no está configurado. Configura WHATCANICOOK_API_BASE_URL '
        'o usa la selección manual de ingredientes.',
      );
    }

    if (!await image.exists()) {
      return const AppFailure('No se encontró la imagen seleccionada.');
    }

    try {
      final uri = Uri.parse('$_baseUrl/api/vision/ingredients');
      final request = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath('image', image.path));

      final streamed = await request.send().timeout(
        const Duration(seconds: 45),
      );
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode != 200) {
        String? serverMessage;
        try {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          serverMessage = body['error'] as String?;
        } catch (_) {}
        return AppFailure(
          serverMessage ??
              'El servidor de IA respondió con el código ${response.statusCode}.',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final items = (decoded['ingredients'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(DetectedIngredient.fromJson)
          .toList();

      return AppSuccess(
        VisionAnalysis(
          ingredients: items,
          model: decoded['model'] as String? ?? 'desconocido',
          warning: decoded['warning'] as String?,
        ),
      );
    } on SocketException {
      return const AppFailure(
        'No se pudo conectar con el servidor de IA. Revisa la red y la URL configurada.',
      );
    } on http.ClientException {
      return const AppFailure('Error de red al enviar la imagen.');
    } catch (error) {
      return AppFailure('Error inesperado al analizar la imagen: $error');
    }
  }

  Future<AppResult<bool>> checkHealth() async {
    if (!isConfigured) return const AppSuccess(false);
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/api/health'))
          .timeout(const Duration(seconds: 8));
      return AppSuccess(response.statusCode == 200);
    } catch (_) {
      return const AppSuccess(false);
    }
  }

  void dispose() => _client.close();
}
