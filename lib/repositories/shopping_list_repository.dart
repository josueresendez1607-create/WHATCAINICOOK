import 'package:whatcanicook/database/database_helper.dart';
import 'package:whatcanicook/models/shopping_item.dart';

class ShoppingListRepository {
  ShoppingListRepository({DatabaseHelper? db})
    : _db = db ?? DatabaseHelper.instance;

  final DatabaseHelper _db;

  Future<List<ShoppingItem>> all() async {
    final db = await _db.database;
    final rows = await db.query(
      'shopping_list',
      orderBy: 'checked ASC, created_at DESC',
    );
    return rows.map(ShoppingItem.fromMap).toList();
  }

  Future<void> addMany(List<ShoppingItem> items) async {
    if (items.isEmpty) return;
    final db = await _db.database;
    final existing = await all();
    final existingKeys = <String>{
      for (final e in existing)
        if (!e.checked) _identity(e.key, e.name),
    };
    final batch = db.batch();
    for (final item in items) {
      final id = _identity(item.key, item.name);
      if (id.isEmpty || existingKeys.contains(id)) continue;
      existingKeys.add(id);
      batch.insert('shopping_list', item.toMap()..remove('id'));
    }
    await batch.commit(noResult: true);
  }

  Future<void> add(ShoppingItem item) async {
    await addMany([item]);
  }

  String _identity(String? key, String name) {
    final k = (key ?? '').trim().toLowerCase();
    if (k.isNotEmpty) return 'k:$k';
    final n = name.trim().toLowerCase();
    return n.isEmpty ? '' : 'n:$n';
  }

  Future<void> toggleChecked(int id, bool checked) async {
    final db = await _db.database;
    await db.update(
      'shopping_list',
      {'checked': checked ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> remove(int id) async {
    final db = await _db.database;
    await db.delete('shopping_list', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearChecked() async {
    final db = await _db.database;
    await db.delete('shopping_list', where: 'checked = 1');
  }

  Future<void> clearAll() async {
    final db = await _db.database;
    await db.delete('shopping_list');
  }
}
