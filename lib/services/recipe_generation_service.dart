import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:whatcanicook/core/config.dart';
import 'package:whatcanicook/core/result.dart';
import 'package:whatcanicook/models/recipe.dart';

/// Resultado de la selección asistida por IA.
///
/// [mode] es `gemini` cuando Gemini seleccionó IDs válidos del catálogo y
/// `local` cuando se aplicó el ranking determinista del catálogo verificado.
class RecipeGenerationResult {
  const RecipeGenerationResult({
    required this.recipes,
    required this.mode,
    required this.selectedIds,
    this.model,
    this.warning,
    this.totalCandidates = 0,
  });

  final List<Recipe> recipes;
  final String mode;
  final List<String> selectedIds;
  final String? model;
  final String? warning;
  final int totalCandidates;

  bool get usedGemini => mode == 'gemini';

  factory RecipeGenerationResult.fromJson(Map<String, dynamic> json) {
    final rawRecipes = json['recipes'];
    if (rawRecipes is! List) {
      throw const FormatException(
        'El backend no devolvió una lista de recetas.',
      );
    }

    final recipes = <Recipe>[];
    for (final item in rawRecipes) {
      if (item is Map<String, dynamic>) {
        recipes.add(Recipe.fromJson(item));
      } else if (item is Map) {
        recipes.add(Recipe.fromJson(Map<String, dynamic>.from(item)));
      }
    }

    final selected = <String>[];
    final rawSelected = json['selected'];
    if (rawSelected is List) {
      for (final item in rawSelected) {
        final id = item.toString();
        if (id.isNotEmpty) selected.add(id);
      }
    }

    final total = json['totalCandidates'];
    return RecipeGenerationResult(
      recipes: recipes,
      mode: json['mode']?.toString() ?? 'local',
      selectedIds: selected,
      model: json['model']?.toString(),
      warning: json['warning']?.toString(),
      totalCandidates: total is num ? total.round() : 0,
    );
  }
}

/// Cliente del endpoint Flask `/api/recipes/generate`.
///
/// La clave de Gemini permanece en el backend; Flutter solo envía ingredientes
/// y filtros, y recibe recetas completas del catálogo verificado.
class RecipeGenerationService {
  RecipeGenerationService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? AppConfig.visionBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  bool get isConfigured => _baseUrl.isNotEmpty;

  Future<AppResult<RecipeGenerationResult>> generate({
    required List<String> ingredients,
    int count = 5,
    List<String> filters = const [],
  }) async {
    if (!isConfigured) {
      return const AppFailure(
        'Modo sin conexión. Usando el catálogo verificado del dispositivo.',
      );
    }

    final uri = Uri.parse('$_baseUrl/api/recipes/generate');
    try {
      final response = await _client
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: _encodeBody(
              ingredients: ingredients,
              count: count,
              filters: filters,
            ),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        return AppFailure(
          _messageFromBody(response.body) ??
              'El backend devolvió HTTP ${response.statusCode}.',
        );
      }

      final value = RecipeGenerationResult.fromJson(_decodeBody(response.body));
      if (value.recipes.isEmpty) {
        return const AppFailure(
          'El backend no devolvió recetas verificadas para esos filtros.',
        );
      }
      return AppSuccess(value);
    } on TimeoutException {
      return const AppFailure(
        'El backend tardó demasiado en responder. Intenta de nuevo.',
      );
    } catch (error) {
      return AppFailure('No se pudo conectar con el backend: $error');
    }
  }

  String _encodeBody({
    required List<String> ingredients,
    required int count,
    required List<String> filters,
  }) {
    // Se codifica manualmente para evitar dependencias adicionales.
    final buffer = StringBuffer()
      ..write('{"ingredients":[')
      ..write(ingredients.map(_jsonString).join(','))
      ..write('],"count":')
      ..write(count)
      ..write(',"filters":[')
      ..write(filters.map(_jsonString).join(','))
      ..write(']}');
    return buffer.toString();
  }

  Map<String, dynamic> _decodeBody(String body) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      throw const FormatException('Respuesta JSON inválida del backend.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('El backend devolvió un objeto inesperado.');
    }
    return decoded;
  }

  String? _messageFromBody(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['error']?.toString();
        if (message != null && message.isNotEmpty) return message;
      }
    } catch (_) {
      // Se usa el mensaje HTTP genérico.
    }
    return null;
  }

  static String _jsonString(String value) {
    final escaped = value
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r')
        .replaceAll('\t', r'\t');
    return '"$escaped"';
  }
}
