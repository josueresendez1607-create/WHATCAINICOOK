import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:whatcanicook/models/ingredient_catalog.dart';
import 'package:whatcanicook/models/recipe.dart';

class CatalogService {
  CatalogService({this.catalogAsset = 'assets/data/ingredients.json'});

  final String catalogAsset;
  IngredientCatalog? _cachedCatalog;
  List<Recipe>? _cachedRecipes;

  Future<IngredientCatalog> loadCatalog() async {
    final cached = _cachedCatalog;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString(catalogAsset);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final catalog = IngredientCatalog.fromJson(decoded);
    _cachedCatalog = catalog;
    return catalog;
  }

  Future<List<Recipe>> loadRecipes({
    String asset = 'assets/data/recipes.json',
  }) async {
    final cached = _cachedRecipes;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString(asset);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final recipes = (decoded['recipes'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Recipe.fromJson)
        .toList()
        .where((recipe) => recipe.verified)
        .toList(growable: false);
    _cachedRecipes = recipes;
    return recipes;
  }
}
