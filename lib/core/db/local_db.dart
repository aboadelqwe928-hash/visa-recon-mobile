import 'dart:convert';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Local offline cache for VisaRecon data.
/// We store JSON blobs keyed by type + period for simplicity and flexibility.
class LocalDb {
  static Database? _db;
  static const _name = 'visa_recon_offline.db';
  static const _version = 1;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  static Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, _name);
    return openDatabase(
      path,
      version: _version,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cache (
            key TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            updated_at INTEGER NOT NULL,
            period_from TEXT,
            period_to TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE meta (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE sync_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            at INTEGER NOT NULL,
            success INTEGER NOT NULL,
            message TEXT
          )
        ''');
      },
    );
  }

  // ---------- Cache ----------
  static Future<void> put(String key, dynamic data, {String? from, String? to}) async {
    final db = await database;
    await db.insert(
      'cache',
      {
        'key': key,
        'data': jsonEncode(data),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'period_from': from,
        'period_to': to,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<Map<String, dynamic>?> get(String key) async {
    final db = await database;
    final rows = await db.query('cache', where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    final raw = rows.first['data'] as String;
    return {
      'data': jsonDecode(raw),
      'updated_at': rows.first['updated_at'],
      'period_from': rows.first['period_from'],
      'period_to': rows.first['period_to'],
    };
  }

  static Future<dynamic> getData(String key) async {
    final row = await get(key);
    return row?['data'];
  }

  static Future<void> remove(String key) async {
    final db = await database;
    await db.delete('cache', where: 'key = ?', whereArgs: [key]);
  }

  static Future<void> clearCache() async {
    final db = await database;
    await db.delete('cache');
  }

  // ---------- Meta ----------
  static Future<void> setMeta(String key, String value) async {
    final db = await database;
    await db.insert('meta', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<String?> getMeta(String key) async {
    final db = await database;
    final rows = await db.query('meta', where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  // ---------- Sync log ----------
  static Future<void> logSync({required bool success, String? message}) async {
    final db = await database;
    await db.insert('sync_log', {
      'at': DateTime.now().millisecondsSinceEpoch,
      'success': success ? 1 : 0,
      'message': message,
    });
    // keep last 50 only
    await db.rawDelete('''
      DELETE FROM sync_log WHERE id NOT IN (
        SELECT id FROM sync_log ORDER BY id DESC LIMIT 50
      )
    ''');
  }

  static Future<List<Map<String, dynamic>>> lastSyncs({int limit = 10}) async {
    final db = await database;
    return db.query('sync_log', orderBy: 'id DESC', limit: limit);
  }

  static Future<DateTime?> lastSuccessfulSync() async {
    final db = await database;
    final rows = await db.query(
      'sync_log',
      where: 'success = 1',
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DateTime.fromMillisecondsSinceEpoch(rows.first['at'] as int);
  }
}
