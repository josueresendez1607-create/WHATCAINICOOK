import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Base de datos local de WHATCANICOOK.
///
/// Se usa una única base con control de versión (`user_version`) para que
/// futuras actualizaciones puedan migrar sin perder los datos del usuario.
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const int _version = 3;
  static const String _name = 'whatcanicook.db';

  Database? _database;
  Future<Database>? _opening;
  DatabaseFactory? _factoryOverride;
  String _databaseName = _name;

  /// Permite aislar la base en pruebas usando un nombre distinto.
  void useFactory(DatabaseFactory factory, {String? databaseName}) {
    _factoryOverride = factory;
    _databaseName = databaseName ?? _name;
    _database = null;
  }

  Future<Database> get database async {
    final existing = _database;
    if (existing != null && existing.isOpen) return existing;

    // Varios providers solicitan la base al iniciar. Compartimos la apertura
    // para no abrir dos veces el mismo archivo y evitar bloqueos de SQLite.
    final opening = _opening;
    if (opening != null) return opening;

    final future = _open();
    _opening = future;
    try {
      final created = await future;
      _database = created;
      return created;
    } finally {
      _opening = null;
    }
  }

  Future<Database> _open() async {
    final factory = _factoryOverride;
    final databasesPath = factory != null
        ? await factory.getDatabasesPath()
        : await getDatabasesPath();
    final path = p.join(databasesPath, _databaseName);

    Future<Database> open() {
      if (factory != null) {
        return factory.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: _version,
            onCreate: _onCreate,
            onUpgrade: _onUpgrade,
          ),
        );
      }
      return openDatabase(
        path,
        version: _version,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    }

    return open();
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();
    batch.execute('''
      CREATE TABLE ingredients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT 'otros',
        quantity TEXT,
        unit TEXT,
        key TEXT,
        source TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
    batch.execute(
      'CREATE UNIQUE INDEX idx_ingredients_name ON ingredients(name COLLATE NOCASE)',
    );
    batch.execute('''
      CREATE TABLE favorites (
        recipe_id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        source_name TEXT NOT NULL,
        source_url TEXT NOT NULL,
        image_url TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
    batch.execute('''
      CREATE TABLE history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kind TEXT NOT NULL,
        value TEXT NOT NULL,
        recipe_id TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_history_created ON history(created_at DESC)',
    );
    batch.execute('''
      CREATE TABLE hidden_recipes (
        recipe_id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_hidden_created ON hidden_recipes(created_at DESC)',
    );
    batch.execute('''
      CREATE TABLE profile (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        name TEXT NOT NULL DEFAULT '',
        vegetarian INTEGER NOT NULL DEFAULT 0,
        gluten_free INTEGER NOT NULL DEFAULT 0,
        high_protein INTEGER NOT NULL DEFAULT 0,
        low_calorie INTEGER NOT NULL DEFAULT 0
      )
    ''');
    batch.execute('''
      CREATE TABLE scans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at INTEGER NOT NULL,
        detected_count INTEGER NOT NULL DEFAULT 0,
        source TEXT NOT NULL
      )
    ''');
    batch.execute('''
      CREATE TABLE preferences (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    batch.execute('''
      CREATE TABLE ai_cache (
        cache_key TEXT PRIMARY KEY,
        kind TEXT NOT NULL,
        value TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_ai_cache_expires ON ai_cache(expires_at DESC)',
    );
    batch.execute('''
      CREATE TABLE shopping_list (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        key TEXT,
        quantity TEXT,
        checked INTEGER NOT NULL DEFAULT 0,
        recipe_id TEXT,
        recipe_title TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_shopping_created ON shopping_list(created_at DESC)',
    );
    batch.execute("INSERT INTO profile (id) VALUES (1)");
    await batch.commit(noResult: true);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS hidden_recipes (
          recipe_id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          created_at INTEGER NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_hidden_created '
        'ON hidden_recipes(created_at DESC)',
      );
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ai_cache (
          cache_key TEXT PRIMARY KEY,
          kind TEXT NOT NULL,
          value TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          expires_at INTEGER NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_ai_cache_expires ON ai_cache(expires_at DESC)',
      );
      await db.execute('''
        CREATE TABLE IF NOT EXISTS shopping_list (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          key TEXT,
          quantity TEXT,
          checked INTEGER NOT NULL DEFAULT 0,
          recipe_id TEXT,
          recipe_title TEXT,
          created_at INTEGER NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_shopping_created ON shopping_list(created_at DESC)',
      );
    }
  }

  Future<void> close() async {
    final opening = _opening;
    if (opening != null) {
      try {
        await opening;
      } catch (_) {}
    }
    final db = _database;
    if (db != null && db.isOpen) await db.close();
    _database = null;
  }
}
