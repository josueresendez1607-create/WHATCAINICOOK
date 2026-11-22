import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

  static final Map<String, VisionAnalysis> _cache = <String, VisionAnalysis>{};
  static final Map<String, Future<AppResult<VisionAnalysis>>> _inFlight =
      <String, Future<AppResult<VisionAnalysis>>>{};
  static DateTime? _cooldownUntil;

  bool get isConfigured => _baseUrl.isNotEmpty;

  static bool get _inCooldown =>
      _cooldownUntil != null && DateTime.now().isBefore(_cooldownUntil!);

  static void _setCooldown([Duration duration = const Duration(seconds: 90)]) {
    final until = DateTime.now().add(duration);
    if (_cooldownUntil == null || until.isAfter(_cooldownUntil!)) {
      _cooldownUntil = until;
    }
  }

  static String _fingerprint(Uint8List bytes) {
    // FNV-1a 64-bit simple para dedupe/caché local.
    var hash = 0xcbf29ce484222325;
    const prime = 0x100000001b3;
    for (final b in bytes) {
      hash ^= b;
      hash = (hash * prime) & 0xFFFFFFFFFFFFFFFF;
    }
    return '${bytes.length}:$hash';
  }

  Future<AppResult<VisionAnalysis>> analyze(File image) async {
    if (!isConfigured) {
      return const AppFailure(
        'El análisis de fotos no está disponible sin conexión. '
        'Puedes agregar ingredientes manualmente.',
      );
    }

    if (!await image.exists()) {
      return const AppFailure('No se encontró la imagen seleccionada.');
    }

    Uint8List bytes;
    try {
      bytes = await image.readAsBytes();
    } catch (_) {
      return const AppFailure('No se pudo leer la imagen seleccionada.');
    }

    final key = _fingerprint(bytes);
    final cached = _cache[key];
    if (cached != null) return AppSuccess(cached);

    if (_inCooldown) {
      return const AppFailure(
        'Se alcanzó el límite gratuito del servicio de IA. '
        'Intenta de nuevo más tarde o agrega ingredientes manualmente.',
      );
    }

    final inFlight = _inFlight[key];
    if (inFlight != null) return inFlight;

    final future = _analyzeBytes(bytes, key);
    _inFlight[key] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<AppResult<VisionAnalysis>> _analyzeBytes(
    Uint8List bytes,
    String key,
  ) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/vision/ingredients');
      final request = http.MultipartRequest('POST', uri)
        ..files.add(
          http.MultipartFile.fromBytes('image', bytes, filename: 'photo.jpg'),
        );

      final streamed = await request.send().timeout(
        const Duration(seconds: 45),
      );
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode != 200) {
        String? serverMessage;
        int? upstreamStatus;
        try {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          serverMessage = body['error'] as String?;
          final up = body['upstream_status'];
          if (up is num) upstreamStatus = up.toInt();
        } catch (_) {}
        if (response.statusCode == 429 || upstreamStatus == 429) {
          _setCooldown();
        }
        return AppFailure(
          serverMessage ??
              'No se pudo analizar la foto en este momento. '
                  'Puedes agregar ingredientes manualmente.',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final items = (decoded['ingredients'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(DetectedIngredient.fromJson)
          .toList();

      final analysis = VisionAnalysis(
        ingredients: items,
        model: decoded['model'] as String? ?? 'desconocido',
        warning: decoded['warning'] as String?,
      );
      _cache[key] = analysis;
      return AppSuccess(analysis);
    } on SocketException {
      return const AppFailure(
        'No se pudo conectar con el servicio de IA. '
        'Puedes agregar ingredientes manualmente.',
      );
    } on http.ClientException {
      return const AppFailure(
        'No se pudo conectar con el servicio de IA. '
        'Puedes agregar ingredientes manualmente.',
      );
    } catch (_) {
      return const AppFailure(
        'No se pudo analizar la foto en este momento. '
        'Puedes agregar ingredientes manualmente.',
      );
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
