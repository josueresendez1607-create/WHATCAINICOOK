import 'package:whatcanicook/database/database_helper.dart';
import 'package:whatcanicook/models/user_profile.dart';

class HistoryRepository {
  HistoryRepository({DatabaseHelper? helper})
    : _helper = helper ?? DatabaseHelper.instance;

  final DatabaseHelper _helper;

  Future<List<HistoryEntry>> recent({int limit = 30, String? kind}) async {
    final db = await _helper.database;
    final rows = await db.query(
      'history',
      where: kind == null ? null : 'kind = ?',
      whereArgs: kind == null ? null : [kind],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(HistoryEntry.fromMap).toList();
  }

  Future<void> add(String kind, String value, {String? recipeId}) async {
    final db = await _helper.database;
    await db.insert(
      'history',
      HistoryEntry(
        kind: kind,
        value: value,
        recipeId: recipeId,
        createdAt: DateTime.now(),
      ).toMap()..remove('id'),
    );
  }

  Future<int> remove(int id) async {
    final db = await _helper.database;
    return db.delete('history', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> clear() async {
    final db = await _helper.database;
    return db.delete('history');
  }
}
