import 'package:sqflite/sqflite.dart';
import 'package:whatcanicook/database/database_helper.dart';
import 'package:whatcanicook/models/user_profile.dart';

class ProfileRepository {
  ProfileRepository({DatabaseHelper? helper})
    : _helper = helper ?? DatabaseHelper.instance;

  final DatabaseHelper _helper;

  Future<UserProfile> load() async {
    final db = await _helper.database;
    final rows = await db.query('profile', where: 'id = 1', limit: 1);
    if (rows.isEmpty) return UserProfile.empty;
    return UserProfile.fromMap(rows.first);
  }

  Future<void> save(UserProfile profile) async {
    final db = await _helper.database;
    await db.update(
      'profile',
      profile.toMap(),
      where: 'id = 1',
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> readPreference(String key) async {
    final db = await _helper.database;
    final rows = await db.query(
      'preferences',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> writePreference(String key, String value) async {
    final db = await _helper.database;
    await db.insert('preferences', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
