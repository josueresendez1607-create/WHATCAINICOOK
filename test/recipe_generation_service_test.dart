import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:whatcanicook/core/result.dart';
import 'package:whatcanicook/services/recipe_generation_service.dart';

Map<String, dynamic> _recipeJson(String id) => {
  'id': id,
  'title': 'Receta de prueba $id',
  'originalTitle': '',
  'description': 'Descripción verificada.',
  'sourceName': 'MyPlate (USDA)',
  'sourceUrl': 'https://www.myplate.gov/recipes/$id',
  'originalSource': 'USDA',
  'prepMinutes': 10,
  'cookMinutes': 5,
  'difficulty': 'Fácil',
  'difficultyIsEstimated': true,
  'servings': 2,
  'tags': ['comida', 'saludable'],
  'ingredients': [
    {'key': 'tomate', 'quantityText': '1 taza'},
  ],
  'steps': ['Paso 1'],
  'nutrition': {'calories': 180, 'proteinG': 8},
  'imageUrl': 'assets/images/recipes/myplate-frittata-jardin.jpg',
  'verified': true,
};

void main() {
  test('parsea la selección verificada devuelta por el backend', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/recipes/generate');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['ingredients'], ['tomate', 'frijol']);
      expect(body['count'], 2);
      expect(body['filters'], ['comida']);

      return http.Response(
        jsonEncode({
          'mode': 'gemini',
          'model': 'gemini-3.8-flash',
          'selected': ['r1', 'r2'],
          'recipes': [_recipeJson('r1'), _recipeJson('r2')],
          'reasons': {'r1': 'Buena coincidencia'},
          'filledLocally': [],
          'totalCandidates': 13,
          'verifiedOnly': true,
          'warning': null,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final service = RecipeGenerationService(
      client: client,
      baseUrl: 'http://localhost:5000',
    );
    final result = await service.generate(
      ingredients: const ['tomate', 'frijol'],
      count: 2,
      filters: const ['comida'],
    );

    expect(result, isA<AppSuccess<RecipeGenerationResult>>());
    final success = result as AppSuccess<RecipeGenerationResult>;
    expect(success.value.usedGemini, isTrue);
    expect(success.value.recipes, hasLength(2));
    expect(success.value.recipes.first.id, 'r1');
    expect(success.value.selectedIds, ['r1', 'r2']);
    expect(success.value.totalCandidates, 13);
  });

  test('expone el mensaje de error del backend', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({'error': 'No hay recetas para esos filtros.'}),
        422,
        headers: {'content-type': 'application/json'},
      );
    });

    final service = RecipeGenerationService(
      client: client,
      baseUrl: 'http://localhost:5000',
    );
    final result = await service.generate(ingredients: const ['tomate']);

    expect(result, isA<AppFailure<RecipeGenerationResult>>());
    expect(
      (result as AppFailure<RecipeGenerationResult>).message,
      'No hay recetas para esos filtros.',
    );
  });

  test('falla con mensaje claro si no hay backend configurado', () async {
    final service = RecipeGenerationService(
      client: MockClient((request) async => http.Response('{}', 200)),
      baseUrl: '',
    );
    final result = await service.generate(ingredients: const ['tomate']);

    expect(result, isA<AppFailure<RecipeGenerationResult>>());
    expect(
      (result as AppFailure<RecipeGenerationResult>).message,
      contains('Modo sin conexión'),
    );
  });
}
