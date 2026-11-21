class RecipeIngredient {
  const RecipeIngredient({required this.key, required this.quantityText});

  final String key;
  final String quantityText;

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      key: json['key'] as String? ?? '',
      quantityText: json['quantityText'] as String? ?? '',
    );
  }
}

class Nutrition {
  const Nutrition({this.calories, this.proteinG, this.carbsG, this.fatG});

  final int? calories;
  final int? proteinG;
  final int? carbsG;
  final int? fatG;

  bool get hasAny =>
      calories != null || proteinG != null || carbsG != null || fatG != null;

  factory Nutrition.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const Nutrition();
    int? read(String key) {
      final value = json[key];
      return value is num ? value.round() : null;
    }

    return Nutrition(
      calories: read('calories'),
      proteinG: read('proteinG'),
      carbsG: read('carbsG'),
      fatG: read('fatG'),
    );
  }
}

class Recipe {
  const Recipe({
    required this.id,
    required this.title,
    required this.originalTitle,
    required this.description,
    required this.sourceName,
    required this.sourceUrl,
    required this.originalSource,
    required this.prepMinutes,
    required this.cookMinutes,
    required this.difficulty,
    required this.difficultyIsEstimated,
    required this.servings,
    required this.tags,
    required this.ingredients,
    required this.steps,
    required this.nutrition,
    required this.imageUrl,
    required this.verified,
  });

  final String id;
  final String title;
  final String originalTitle;
  final String description;
  final String sourceName;
  final String sourceUrl;
  final String originalSource;
  final int? prepMinutes;
  final int? cookMinutes;
  final String difficulty;
  final bool difficultyIsEstimated;
  final int servings;
  final List<String> tags;
  final List<RecipeIngredient> ingredients;
  final List<String> steps;
  final Nutrition nutrition;
  final String? imageUrl;
  final bool verified;

  int? get totalMinutes {
    if (prepMinutes == null && cookMinutes == null) return null;
    return (prepMinutes ?? 0) + (cookMinutes ?? 0);
  }

  bool get isVegetarian => tags.contains('vegetariana');
  bool get isQuick => (totalMinutes ?? 999) <= 20;
  bool get isLowCalorie => (nutrition.calories ?? 9999) <= 200;
  bool get isHighProtein => (nutrition.proteinG ?? 0) >= 15;

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      originalTitle: json['originalTitle'] as String? ?? '',
      description: json['description'] as String? ?? '',
      sourceName: json['sourceName'] as String? ?? 'Fuente no especificada',
      sourceUrl: json['sourceUrl'] as String? ?? '',
      originalSource: json['originalSource'] as String? ?? '',
      prepMinutes: json['prepMinutes'] as int?,
      cookMinutes: json['cookMinutes'] as int?,
      difficulty: json['difficulty'] as String? ?? 'No indicado',
      difficultyIsEstimated: json['difficultyIsEstimated'] as bool? ?? false,
      servings: json['servings'] as int? ?? 1,
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      ingredients: (json['ingredients'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(RecipeIngredient.fromJson)
          .toList(),
      steps: (json['steps'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      nutrition: Nutrition.fromJson(json['nutrition'] as Map<String, dynamic>?),
      imageUrl: json['imageUrl'] as String?,
      verified: json['verified'] as bool? ?? false,
    );
  }
}
