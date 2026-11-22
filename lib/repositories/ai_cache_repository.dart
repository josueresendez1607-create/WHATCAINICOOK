import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:whatcanicook/database/database_helper.dart';

class AiCacheRepository {
  AiCacheRepository({DatabaseHelper? db}) : _db = db ?? DatabaseHelper.instance;

  final DatabaseHelper _db;

  Future<Map<String, dynamic>?> get(String key, {required String kind}) async {
    final db = await _db.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query(
      'ai_cache',
      where: 'cache_key = ? AND kind = ? AND expires_at > ?',
      whereArgs: [key, kind, now],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final raw = rows.first['value'] as String?;
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  Future<void> set(
    String key, {
    required String kind,
    required Map<String, dynamic> value,
    Duration ttl = const Duration(minutes: 30),
  }) async {
    final db = await _db.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('ai_cache', {
      'cache_key': key,
      'kind': kind,
      'value': jsonEncode(value),
      'created_at': now,
      'expires_at': now + ttl.inMilliseconds,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> clearExpired() async {
    final db = await _db.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.delete('ai_cache', where: 'expires_at <= ?', whereArgs: [now]);
  }
}
