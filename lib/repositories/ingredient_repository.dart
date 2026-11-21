import 'package:sqflite/sqflite.dart';
import 'package:whatcanicook/database/database_helper.dart';
import 'package:whatcanicook/models/ingredient.dart';

class IngredientRepository {
  IngredientRepository({DatabaseHelper? helper})
    : _helper = helper ?? DatabaseHelper.instance;

  final DatabaseHelper _helper;

  Future<List<Ingredient>> all() async {
    final db = await _helper.database;
    final rows = await db.query('ingredients', orderBy: 'created_at DESC');
    return rows.map(Ingredient.fromMap).toList();
  }

  Future<Ingredient> add(Ingredient ingredient) async {
    final db = await _helper.database;
    final map = ingredient.toMap()..remove('id');
    map['created_at'] ??= DateTime.now().millisecondsSinceEpoch;
    final id = await db.insert(
      'ingredients',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return ingredient.copyWith(id: id);
  }

  Future<List<Ingredient>> addMany(List<Ingredient> ingredients) async {
    final added = <Ingredient>[];
    for (final ingredient in ingredients) {
      added.add(await add(ingredient));
    }
    return added;
  }

  Future<int> update(Ingredient ingredient) async {
    final db = await _helper.database;
    if (ingredient.id == null) return 0;
    return db.update(
      'ingredients',
      ingredient.toMap()
        ..remove('id')
        ..remove('created_at'),
      where: 'id = ?',
      whereArgs: [ingredient.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _helper.database;
    return db.delete('ingredients', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> clear() async {
    final db = await _helper.database;
    return db.delete('ingredients');
  }

  Future<int> count() async {
    final db = await _helper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM ingredients',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
