class UserProfile {
  const UserProfile({
    this.name = '',
    this.vegetarian = false,
    this.glutenFree = false,
    this.highProtein = false,
    this.lowCalorie = false,
  });

  final String name;
  final bool vegetarian;
  final bool glutenFree;
  final bool highProtein;
  final bool lowCalorie;

  static const empty = UserProfile();

  UserProfile copyWith({
    String? name,
    bool? vegetarian,
    bool? glutenFree,
    bool? highProtein,
    bool? lowCalorie,
  }) {
    return UserProfile(
      name: name ?? this.name,
      vegetarian: vegetarian ?? this.vegetarian,
      glutenFree: glutenFree ?? this.glutenFree,
      highProtein: highProtein ?? this.highProtein,
      lowCalorie: lowCalorie ?? this.lowCalorie,
    );
  }

  List<String> get activePreferenceLabels {
    final labels = <String>[];
    if (vegetarian) labels.add('Vegetariano');
    if (glutenFree) labels.add('Sin gluten');
    if (highProtein) labels.add('Alto en proteínas');
    if (lowCalorie) labels.add('Bajo en calorías');
    return labels;
  }

  Map<String, Object?> toMap() => {
    'name': name,
    'vegetarian': vegetarian ? 1 : 0,
    'gluten_free': glutenFree ? 1 : 0,
    'high_protein': highProtein ? 1 : 0,
    'low_calorie': lowCalorie ? 1 : 0,
  };

  factory UserProfile.fromMap(Map<String, Object?> map) {
    bool b(String key) => (map[key] as int?) == 1 || map[key] == true;
    return UserProfile(
      name: map['name'] as String? ?? '',
      vegetarian: b('vegetarian'),
      glutenFree: b('gluten_free'),
      highProtein: b('high_protein'),
      lowCalorie: b('low_calorie'),
    );
  }
}

class HistoryEntry {
  const HistoryEntry({
    this.id,
    required this.kind,
    required this.value,
    this.recipeId,
    required this.createdAt,
  });

  final int? id;
  final String kind;
  final String value;
  final String? recipeId;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'kind': kind,
    'value': value,
    'recipe_id': recipeId,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  factory HistoryEntry.fromMap(Map<String, Object?> map) {
    final raw = map['created_at'];
    return HistoryEntry(
      id: map['id'] as int?,
      kind: map['kind'] as String? ?? 'busqueda',
      value: map['value'] as String? ?? '',
      recipeId: map['recipe_id'] as String?,
      createdAt: raw is int
          ? DateTime.fromMillisecondsSinceEpoch(raw)
          : DateTime.now(),
    );
  }
}

class FavoriteRecipe {
  const FavoriteRecipe({
    required this.recipeId,
    required this.title,
    required this.sourceName,
    required this.sourceUrl,
    this.imageUrl,
    required this.createdAt,
  });

  final String recipeId;
  final String title;
  final String sourceName;
  final String sourceUrl;
  final String? imageUrl;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
    'recipe_id': recipeId,
    'title': title,
    'source_name': sourceName,
    'source_url': sourceUrl,
    'image_url': imageUrl,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  factory FavoriteRecipe.fromMap(Map<String, Object?> map) {
    final raw = map['created_at'];
    return FavoriteRecipe(
      recipeId: map['recipe_id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      sourceName: map['source_name'] as String? ?? '',
      sourceUrl: map['source_url'] as String? ?? '',
      imageUrl: map['image_url'] as String?,
      createdAt: raw is int
          ? DateTime.fromMillisecondsSinceEpoch(raw)
          : DateTime.now(),
    );
  }
}
