import 'package:whatcanicook/models/recipe.dart';
import 'package:whatcanicook/models/recipe_match.dart';
import 'package:whatcanicook/models/user_profile.dart';

/// Motor de coincidencias puro (sin E/S), por lo que es fácil de probar.
class RecipeMatcher {
  const RecipeMatcher();

  static const Map<String, Set<String>> _equivalents = {
    'tomate': {'tomate', 'tomate_dados', 'tomate_estofado'},
    'tomate_dados': {'tomate', 'tomate_dados', 'tomate_estofado'},
    'tomate_estofado': {'tomate', 'tomate_dados', 'tomate_estofado'},
    'frijol': {'frijol', 'frijol_negro'},
    'frijol_negro': {'frijol', 'frijol_negro'},
    'limon': {'limon', 'limon_zumo'},
    'limon_zumo': {'limon', 'limon_zumo'},
    'aceite': {'aceite'},
    'chile_polvo': {'chile_polvo'},
    'huevo': {'huevo'},
  };

  List<RecipeMatch> match({
    required List<Recipe> recipes,
    required Set<String> availableKeys,
    List<RecipeFilter> filters = const [],
    RecipeSort sort = RecipeSort.match,
    UserProfile profile = UserProfile.empty,
  }) {
    final wantedTags = filters.map((f) => f.tag).toSet();

    final matches = recipes
        .where((recipe) {
          if (profile.vegetarian && !recipe.isVegetarian) return false;
          if (profile.lowCalorie && !recipe.isLowCalorie) return false;
          if (profile.highProtein && !recipe.isHighProtein) return false;
          if (profile.glutenFree && recipe.tags.contains('con_gluten')) {
            return false;
          }
          if (wantedTags.isEmpty) return true;
          return recipe.tags.any(wantedTags.contains);
        })
        .map((recipe) {
          final uniqueKeys = <String>{};
          for (final ingredient in recipe.ingredients) {
            if (ingredient.key.isNotEmpty) uniqueKeys.add(ingredient.key);
          }

          final matched = <String>{};
          final missing = <RecipeIngredient>[];
          for (final key in uniqueKeys) {
            if (_hasAvailable(key, availableKeys)) {
              matched.add(key);
            } else {
              final first = recipe.ingredients.firstWhere(
                (item) => item.key == key,
                orElse: () => RecipeIngredient(key: key, quantityText: ''),
              );
              missing.add(first);
            }
          }

          final score = uniqueKeys.isEmpty
              ? 0.0
              : matched.length / uniqueKeys.length.toDouble();

          return RecipeMatch(
            recipe: recipe,
            matchedKeys: matched.toList(),
            missing: missing,
            matchScore: score,
          );
        })
        .toList();

    switch (sort) {
      case RecipeSort.match:
        matches.sort((a, b) => b.matchScore.compareTo(a.matchScore));
        break;
      case RecipeSort.missing:
        matches.sort((a, b) => a.missingCount.compareTo(b.missingCount));
        break;
      case RecipeSort.time:
        matches.sort(
          (a, b) => (a.recipe.totalMinutes ?? 100000).compareTo(
            b.recipe.totalMinutes ?? 100000,
          ),
        );
        break;
      case RecipeSort.difficulty:
        final order = {'Fácil': 0, 'Media': 1, 'Difícil': 2};
        matches.sort(
          (a, b) => (order[a.recipe.difficulty] ?? 0).compareTo(
            order[b.recipe.difficulty] ?? 0,
          ),
        );
        break;
    }

    return matches;
  }

  bool _hasAvailable(String needed, Set<String> available) {
    if (available.contains(needed)) return true;
    final group = _equivalents[needed];
    if (group == null) return false;
    return available.any(group.contains);
  }
}
