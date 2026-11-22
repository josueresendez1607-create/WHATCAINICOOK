import 'package:sqflite/sqflite.dart';
import 'package:whatcanicook/database/database_helper.dart';
import 'package:whatcanicook/models/recipe.dart';
import 'package:whatcanicook/models/user_profile.dart';

class FavoriteRepository {
  FavoriteRepository({DatabaseHelper? helper})
    : _helper = helper ?? DatabaseHelper.instance;

  final DatabaseHelper _helper;

  Future<List<FavoriteRecipe>> all() async {
    final db = await _helper.database;
    final rows = await db.query('favorites', orderBy: 'created_at DESC');
    return rows.map(FavoriteRecipe.fromMap).toList();
  }

  Future<bool> isFavorite(String recipeId) async {
    final db = await _helper.database;
    final rows = await db.query(
      'favorites',
      columns: ['recipe_id'],
      where: 'recipe_id = ?',
      whereArgs: [recipeId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> save(Recipe recipe) async {
    final db = await _helper.database;
    await db.insert(
      'favorites',
      FavoriteRecipe(
        recipeId: recipe.id,
        title: recipe.title,
        sourceName: recipe.sourceName,
        sourceUrl: recipe.sourceUrl,
        imageUrl: recipe.imageUrl,
        createdAt: DateTime.now(),
      ).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Restaura un favorito con su fecha original (para deshacer una eliminación).
  Future<void> restore(FavoriteRecipe item) async {
    final db = await _helper.database;
    await db.insert(
      'favorites',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> remove(String recipeId) async {
    final db = await _helper.database;
    return db.delete(
      'favorites',
      where: 'recipe_id = ?',
      whereArgs: [recipeId],
    );
  }

  Future<void> toggle(Recipe recipe) async {
    if (await isFavorite(recipe.id)) {
      await remove(recipe.id);
    } else {
      await save(recipe);
    }
  }
}
