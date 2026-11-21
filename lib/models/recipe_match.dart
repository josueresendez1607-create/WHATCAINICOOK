import 'package:whatcanicook/models/recipe.dart';

class RecipeMatch {
  const RecipeMatch({
    required this.recipe,
    required this.matchedKeys,
    required this.missing,
    required this.matchScore,
  });

  final Recipe recipe;
  final List<String> matchedKeys;
  final List<RecipeIngredient> missing;
  final double matchScore;

  int get missingCount => missing.length;
  int get matchedCount => matchedKeys.length;
}

enum RecipeSort {
  match('Mayor coincidencia'),
  missing('Menos ingredientes faltantes'),
  time('Menor tiempo'),
  difficulty('Dificultad');

  const RecipeSort(this.label);
  final String label;
}

enum RecipeFilter {
  desayuno('Desayuno', 'desayuno'),
  comida('Comida', 'comida'),
  cena('Cena', 'cena'),
  postres('Postres', 'postres'),
  saludable('Saludable', 'saludable'),
  rapida('Rápida', 'rapida'),
  economica('Económica', 'economica'),
  altaProteinas('Alta en proteínas', 'alta_en_proteinas'),
  bajaCalorias('Baja en calorías', 'baja_en_calorias'),
  vegetariana('Vegetariana', 'vegetariana');

  const RecipeFilter(this.label, this.tag);
  final String label;
  final String tag;
}
