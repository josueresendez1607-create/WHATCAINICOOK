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

  static final Map<String, RecipeGenerationResult> _cache =
      <String, RecipeGenerationResult>{};
  static final Map<String, Future<AppResult<RecipeGenerationResult>>>
  _inFlight = <String, Future<AppResult<RecipeGenerationResult>>>{};
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

  static String _cacheKey({
    required List<String> ingredients,
    required int count,
    required List<String> filters,
  }) {
    final normIngredients =
        ingredients
            .map((e) => e.trim().toLowerCase())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final normFilters =
        filters
            .map((e) => e.trim().toLowerCase())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return jsonEncode({'i': normIngredients, 'f': normFilters, 'c': count});
  }

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

    final key = _cacheKey(
      ingredients: ingredients,
      count: count,
      filters: filters,
    );
    final cached = _cache[key];
    if (cached != null) return AppSuccess(cached);

    if (_inCooldown) {
      return const AppFailure(
        'Se alcanzó el límite gratuito del servicio de IA. '
        'Mostrando recetas del catálogo verificado.',
      );
    }

    final inFlight = _inFlight[key];
    if (inFlight != null) return inFlight;

    final future = _generateRemote(
      ingredients: ingredients,
      count: count,
      filters: filters,
      key: key,
    );
    _inFlight[key] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<AppResult<RecipeGenerationResult>> _generateRemote({
    required List<String> ingredients,
    required int count,
    required List<String> filters,
    required String key,
  }) async {
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
        int? upstreamStatus;
        String? serverMessage;
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            serverMessage = decoded['error']?.toString();
            final up = decoded['upstream_status'];
            if (up is num) upstreamStatus = up.toInt();
          }
        } catch (_) {}
        if (response.statusCode == 429 || upstreamStatus == 429) {
          _setCooldown();
        }
        return AppFailure(
          serverMessage ??
              'No se pudo generar recetas en este momento. '
                  'Intenta de nuevo más tarde.',
        );
      }

      final value = RecipeGenerationResult.fromJson(_decodeBody(response.body));
      if (value.recipes.isEmpty) {
        return const AppFailure(
          'El backend no devolvió recetas verificadas para esos filtros.',
        );
      }
      // Cachea resultados; si fue local por límite, el backend ya controla cooldown.
      _cache[key] = value;
      return AppSuccess(value);
    } on TimeoutException {
      return const AppFailure(
        'El backend tardó demasiado en responder. Intenta de nuevo.',
      );
    } catch (_) {
      return const AppFailure(
        'No se pudo conectar con el servicio de recetas. '
        'Intenta de nuevo más tarde.',
      );
    }
  }

  String _encodeBody({
    required List<String> ingredients,
    required int count,
    required List<String> filters,
  }) {
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
