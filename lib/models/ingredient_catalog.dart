import 'package:whatcanicook/utils/normalization.dart';

class CatalogCategory {
  const CatalogCategory({required this.id, required this.label});

  final String id;
  final String label;

  factory CatalogCategory.fromJson(Map<String, dynamic> json) {
    return CatalogCategory(
      id: json['id'] as String? ?? 'otros',
      label: json['label'] as String? ?? 'Otros',
    );
  }
}

class CatalogIngredient {
  const CatalogIngredient({
    required this.key,
    required this.name,
    required this.category,
    required this.aliases,
  });

  final String key;
  final String name;
  final String category;
  final List<String> aliases;

  List<String> get normalizedAliases =>
      aliases.map(normalizeIngredient).toList();

  factory CatalogIngredient.fromJson(Map<String, dynamic> json) {
    return CatalogIngredient(
      key: json['key'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? 'otros',
      aliases: (json['aliases'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class IngredientCatalog {
  const IngredientCatalog({
    required this.version,
    required this.categories,
    required this.ingredients,
  });

  final int version;
  final List<CatalogCategory> categories;
  final List<CatalogIngredient> ingredients;

  String? resolveKey(String name) {
    final normalized = normalizeIngredient(name);
    if (normalized.isEmpty) return null;

    CatalogIngredient? best;
    var bestLength = 0;

    for (final item in ingredients) {
      for (final alias in item.normalizedAliases) {
        if (alias.isEmpty) continue;
        if (alias == normalized ||
            singularize(alias) == singularize(normalized)) {
          return item.key;
        }
        // Solo se aceptan coincidencias parciales para alias sufficiently
        // largos, evitando falsos positivos con alias cortos como "sal".
        if (alias.length >= 5 && normalized.contains(alias)) {
          if (alias.length > bestLength) {
            best = item;
            bestLength = alias.length;
          }
        }
      }
    }

    return best?.key;
  }

  CatalogIngredient? itemForKey(String key) {
    for (final item in ingredients) {
      if (item.key == key) return item;
    }
    return null;
  }

  String labelForKey(String key) => itemForKey(key)?.name ?? key;

  String categoryLabel(String categoryId) {
    for (final category in categories) {
      if (category.id == categoryId) return category.label;
    }
    return 'Otros';
  }

  List<CatalogIngredient> search(String query, {String? categoryId}) {
    final normalized = normalizeIngredient(query);
    return ingredients.where((item) {
      if (categoryId != null &&
          categoryId != 'todos' &&
          item.category != categoryId) {
        return false;
      }
      if (normalized.isEmpty) return true;
      return item.normalizedAliases.any(
            (alias) => alias.contains(normalized),
          ) ||
          normalizeIngredient(item.name).contains(normalized);
    }).toList();
  }

  factory IngredientCatalog.fromJson(Map<String, dynamic> json) {
    return IngredientCatalog(
      version: json['version'] as int? ?? 1,
      categories: (json['categories'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CatalogCategory.fromJson)
          .toList(),
      ingredients: (json['ingredients'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CatalogIngredient.fromJson)
          .toList(),
    );
  }
}
