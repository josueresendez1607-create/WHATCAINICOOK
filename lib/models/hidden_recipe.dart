/// Platillo que el usuario decidió ocultar de listados y recomendaciones.
///
/// Se guarda en SQLite para que la decisión persista tras reiniciar la app.
class HiddenRecipe {
  const HiddenRecipe({
    required this.recipeId,
    required this.title,
    required this.createdAt,
  });

  final String recipeId;
  final String title;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
    'recipe_id': recipeId,
    'title': title,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  factory HiddenRecipe.fromMap(Map<String, Object?> map) {
    final raw = map['created_at'];
    return HiddenRecipe(
      recipeId: map['recipe_id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      createdAt: raw is int
          ? DateTime.fromMillisecondsSinceEpoch(raw)
          : DateTime.now(),
    );
  }
}
