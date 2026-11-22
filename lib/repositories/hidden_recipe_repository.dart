import 'package:sqflite/sqflite.dart';
import 'package:whatcanicook/database/database_helper.dart';
import 'package:whatcanicook/models/hidden_recipe.dart';

class HiddenRecipeRepository {
  HiddenRecipeRepository({DatabaseHelper? helper})
    : _helper = helper ?? DatabaseHelper.instance;

  final DatabaseHelper _helper;

  Future<List<HiddenRecipe>> all() async {
    final db = await _helper.database;
    final rows = await db.query('hidden_recipes', orderBy: 'created_at DESC');
    return rows.map(HiddenRecipe.fromMap).toList();
  }

  Future<bool> isHidden(String recipeId) async {
    final db = await _helper.database;
    final rows = await db.query(
      'hidden_recipes',
      columns: ['recipe_id'],
      where: 'recipe_id = ?',
      whereArgs: [recipeId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> hide(String recipeId, String title) async {
    final db = await _helper.database;
    await db.insert(
      'hidden_recipes',
      HiddenRecipe(
        recipeId: recipeId,
        title: title,
        createdAt: DateTime.now(),
      ).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> unhide(String recipeId) async {
    final db = await _helper.database;
    return db.delete(
      'hidden_recipes',
      where: 'recipe_id = ?',
      whereArgs: [recipeId],
    );
  }

  Future<int> clear() async {
    final db = await _helper.database;
    return db.delete('hidden_recipes');
  }
}
