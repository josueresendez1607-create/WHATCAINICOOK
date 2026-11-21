import 'package:flutter_test/flutter_test.dart';
import 'package:whatcanicook/models/recipe.dart';
import 'package:whatcanicook/models/recipe_match.dart';
import 'package:whatcanicook/models/user_profile.dart';
import 'package:whatcanicook/services/recipe_matcher.dart';

Recipe _recipe({
  required String id,
  required List<String> keys,
  int? calories = 180,
  int? protein = 10,
  List<String> tags = const ['comida'],
}) {
  return Recipe.fromJson({
    'id': id,
    'title': id,
    'description': 'desc',
    'sourceName': 'MyPlate (USDA)',
    'sourceUrl': 'https://www.myplate.gov/recipes/$id',
    'originalSource': 'USDA',
    'prepMinutes': 10,
    'cookMinutes': null,
    'difficulty': 'Fácil',
    'difficultyIsEstimated': true,
    'servings': 2,
    'tags': tags,
    'ingredients': [
      for (final key in keys) {'key': key, 'quantityText': '1 unidad'},
    ],
    'steps': ['Paso 1'],
    'nutrition': {
      'calories': calories,
      'proteinG': protein,
      'carbsG': 20,
      'fatG': 5,
    },
    'verified': true,
  });
}

void main() {
  final matcher = const RecipeMatcher();
  final recipes = [
    _recipe(id: 'a', keys: ['tomate', 'cebolla', 'sal']),
    _recipe(id: 'b', keys: ['tomate', 'pollo', 'arroz', 'sal']),
    _recipe(
      id: 'vegetariana',
      keys: ['tomate'],
      tags: const ['comida', 'vegetariana', 'saludable'],
    ),
  ];

  test('ordena por mayor coincidencia', () {
    final result = matcher.match(
      recipes: recipes,
      availableKeys: {'tomate', 'cebolla', 'sal'},
    );
    expect(result.first.recipe.id, 'a');
    expect(result.first.matchScore, 1.0);
    expect(result.first.missing, isEmpty);
  });

  test('calcula ingredientes faltantes', () {
    final result = matcher.match(recipes: recipes, availableKeys: {'tomate'});
    final b = result.firstWhere((item) => item.recipe.id == 'b');
    expect(b.missing.length, 3);
  });

  test('respeta preferencia vegetariana', () {
    final result = matcher.match(
      recipes: recipes,
      availableKeys: {'tomate'},
      profile: const UserProfile(vegetarian: true),
    );
    expect(result.every((item) => item.recipe.isVegetarian), isTrue);
  });

  test('filtra por tag y ordena por menor tiempo', () {
    final result = matcher.match(
      recipes: recipes,
      availableKeys: const {},
      filters: const [RecipeFilter.vegetariana],
      sort: RecipeSort.time,
    );
    expect(result.length, 1);
    expect(result.first.recipe.id, 'vegetariana');
  });
}
