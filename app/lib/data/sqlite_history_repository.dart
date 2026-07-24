import 'dart:convert';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'database_helper.dart';
import 'history_repository.dart';
import 'models/history_entry.dart';
import 'secure_key_storage.dart';

/// Concrete implementation of [HistoryRepository] backed by an encrypted SQLite database.
///
/// Implements CRUD operations, query search, retention purges, and export routines
/// while guaranteeing AES-256 / SQLCipher encryption at rest (TRD S-1, SRS FR-6, FR-9, FR-10).
class SqliteHistoryRepository implements HistoryRepository {
  SqliteHistoryRepository({
    DatabaseHelper? dbHelper,
    SecureKeyStorage? keyStorage,
  })  : _dbHelper = dbHelper ?? DatabaseHelper(),
        _keyStorage = keyStorage ?? SecureKeyStorage();

  final DatabaseHelper _dbHelper;
  final SecureKeyStorage _keyStorage;

  Future<Database> _getDb() async {
    final key = await _keyStorage.getOrCreateDatabaseKey();
    return _dbHelper.getDatabase(key);
  }

  @override
  Future<List<HistoryEntry>> getAllEntries() async {
    final db = await _getDb();
    final maps = await db.query(
      'history_entries',
      orderBy: 'captured_at DESC',
    );
    return maps.map(_mapToEntry).toList();
  }

  @override
  Future<List<HistoryEntry>> search(String query) async {
    final db = await _getDb();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return getAllEntries();
    }

    final maps = await db.query(
      'history_entries',
      where: 'text LIKE ? OR source_app LIKE ? OR category LIKE ?',
      whereArgs: ['%$trimmed%', '%$trimmed%', '%$trimmed%'],
      orderBy: 'captured_at DESC',
    );
    return maps.map(_mapToEntry).toList();
  }

  @override
  Future<List<HistoryEntry>> searchEntries(String query) => search(query);

  @override
  Future<HistoryEntry?> getEntry(String id) async {
    final db = await _getDb();
    final maps = await db.query(
      'history_entries',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) {
      return null;
    }
    return _mapToEntry(maps.first);
  }

  @override
  Future<void> insertEntry(HistoryEntry entry) async {
    final db = await _getDb();
    await db.insert(
      'history_entries',
      _entryToMap(entry),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> addEntry(HistoryEntry entry) => insertEntry(entry);

  @override
  Future<void> deleteEntry(String id) async {
    final db = await _getDb();
    await db.delete(
      'history_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> deleteAllEntries() async {
    final db = await _getDb();
    await db.delete('history_entries');
  }

  @override
  Future<void> clearAll() => deleteAllEntries();

  @override
  Future<int> purgeOlderThan(int retentionDays) async {
    final db = await _getDb();
    final cutoff = DateTime.now()
        .subtract(Duration(days: retentionDays))
        .millisecondsSinceEpoch;

    return db.delete(
      'history_entries',
      where: 'captured_at < ?',
      whereArgs: [cutoff],
    );
  }

  @override
  Future<String> exportAll() async {
    final entries = await getAllEntries();
    final exportData = entries
        .map((e) => {
              'id': e.id,
              'text': e.text,
              'sourceApp': e.sourceApp,
              'capturedAt': e.capturedAt.toIso8601String(),
              'language': e.language,
              'wasTranslated': e.wasTranslated,
              'deviceId': e.deviceId,
              'category': e.category,
              'useCount': e.useCount,
            })
        .toList();
    return const JsonEncoder.withIndent('  ').convert(exportData);
  }

  @override
  Future<int> count() async {
    final db = await _getDb();
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM history_entries');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ── Settings Helpers ──────────────────────────────────────────────

  /// Reads a setting by key.
  Future<String?> getSetting(String key) async {
    final db = await _getDb();
    final maps = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (maps.isEmpty) {
      return null;
    }
    return maps.first['value'] as String?;
  }

  /// Sets a setting key-value pair.
  Future<void> setSetting(String key, String value) async {
    final db = await _getDb();
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── Exclusion List Helpers ────────────────────────────────────────

  @override
  Future<List<String>> getExclusionList() async {
    final db = await _getDb();
    final maps = await db.query('exclusion_list', orderBy: 'added_at ASC');
    return maps.map((m) => m['app_identifier'] as String).toList();
  }

  @override
  Future<void> addExclusion(String appIdentifier) async {
    final db = await _getDb();
    await db.insert(
      'exclusion_list',
      {
        'app_identifier': appIdentifier,
        'added_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> removeExclusion(String appIdentifier) async {
    final db = await _getDb();
    await db.delete(
      'exclusion_list',
      where: 'app_identifier = ?',
      whereArgs: [appIdentifier],
    );
  }

  // ── Mapping Helpers ───────────────────────────────────────────────

  HistoryEntry _mapToEntry(Map<String, dynamic> map) => HistoryEntry(
        id: map['id'] as String,
        text: map['text'] as String,
        sourceApp: map['source_app'] as String,
        capturedAt:
            DateTime.fromMillisecondsSinceEpoch(map['captured_at'] as int),
        language: map['language'] as String?,
        wasTranslated: (map['was_translated'] as int) == 1,
        deviceId: map['device_id'] as String?,
        category: map['category'] as String?,
        useCount: map['use_count'] as int? ?? 0,
      );

  Map<String, dynamic> _entryToMap(HistoryEntry entry) => {
        'id': entry.id,
        'text': entry.text,
        'source_app': entry.sourceApp,
        'captured_at': entry.capturedAt.millisecondsSinceEpoch,
        'language': entry.language,
        'was_translated': entry.wasTranslated ? 1 : 0,
        'device_id': entry.deviceId,
        'category': entry.category,
        'use_count': entry.useCount,
      };
}
