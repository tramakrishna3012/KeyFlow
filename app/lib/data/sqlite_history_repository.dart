import 'package:sqflite_sqlcipher/sqflite.dart';
import 'database_helper.dart';
import 'history_repository.dart';
import 'models/history_entry.dart';
import 'secure_key_storage.dart';

class SqliteHistoryRepository implements HistoryRepository {
  SqliteHistoryRepository({
    required DatabaseHelper dbHelper,
    required SecureKeyStorage keyStorage,
  })  : _dbHelper = dbHelper,
        _keyStorage = keyStorage;


  final DatabaseHelper _dbHelper;
  final SecureKeyStorage _keyStorage;

  @override
  Future<void> addEntry(HistoryEntry entry) async {
    final password = await _keyStorage.getOrCreateDatabaseKey();
    final db = await _dbHelper.getDatabase(password);
    await db.insert(
      'history_entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> insertEntry(HistoryEntry entry) => addEntry(entry);

  @override
  Future<HistoryEntry?> getEntry(String id) async {
    final password = await _keyStorage.getOrCreateDatabaseKey();
    final db = await _dbHelper.getDatabase(password);
    final maps = await db.query(
      'history_entries',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return HistoryEntry.fromMap(maps.first);
  }

  @override
  Future<List<HistoryEntry>> search(String query) async {
    final password = await _keyStorage.getOrCreateDatabaseKey();
    final db = await _dbHelper.getDatabase(password);

    final List<Map<String, dynamic>> maps;
    if (query.isEmpty) {
      maps = await db.query('history_entries', orderBy: 'captured_at DESC');
    } else {
      maps = await db.query(
        'history_entries',
        where: 'text LIKE ? OR source_app LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
        orderBy: 'captured_at DESC',
      );
    }
    return maps.map(HistoryEntry.fromMap).toList();
  }

  @override
  Future<List<HistoryEntry>> searchEntries(String query, {String? appName}) =>
      search(query);

  @override
  Future<List<HistoryEntry>> getAllEntries() async {
    final password = await _keyStorage.getOrCreateDatabaseKey();
    final db = await _dbHelper.getDatabase(password);
    final maps = await db.query('history_entries', orderBy: 'captured_at DESC');
    return maps.map(HistoryEntry.fromMap).toList();
  }

  @override
  Future<void> deleteEntry(String id) async {
    final password = await _keyStorage.getOrCreateDatabaseKey();
    final db = await _dbHelper.getDatabase(password);
    await db.delete('history_entries', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> clearAll() async {
    final password = await _keyStorage.getOrCreateDatabaseKey();
    final db = await _dbHelper.getDatabase(password);
    await db.delete('history_entries');
  }

  @override
  Future<void> deleteAllEntries() => clearAll();

  @override
  Future<int> purgeOlderThan(int retentionDays) async {
    final password = await _keyStorage.getOrCreateDatabaseKey();
    final db = await _dbHelper.getDatabase(password);
    final cutoff = DateTime.now()
        .subtract(Duration(days: retentionDays))
        .millisecondsSinceEpoch;

    return db.delete('history_entries', where: 'captured_at < ?', whereArgs: [cutoff]);
  }

  @override
  Future<int> count() async {
    final password = await _keyStorage.getOrCreateDatabaseKey();
    final db = await _dbHelper.getDatabase(password);
    final result = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM history_entries'),
    );
    return result ?? 0;
  }

  @override
  Future<String> exportAll() async {
    final entries = await getAllEntries();
    return entries.map((e) => '${e.capturedAt.toIso8601String()}\t${e.text}').join('\n');
  }

  @override
  Future<String?> getSetting(String key) async {
    final password = await _keyStorage.getOrCreateDatabaseKey();
    final db = await _dbHelper.getDatabase(password);
    final maps = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return maps.first['value'] as String?;
  }

  @override
  Future<void> setSetting(String key, String value) async {
    final password = await _keyStorage.getOrCreateDatabaseKey();
    final db = await _dbHelper.getDatabase(password);
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<String>> getExclusionList() async {
    final password = await _keyStorage.getOrCreateDatabaseKey();
    final db = await _dbHelper.getDatabase(password);
    final maps = await db.query('exclusion_list');
    return maps.map((m) => m['app_identifier'] as String).toList();
  }

  @override
  Future<void> addExclusion(String appIdentifier) async {
    final password = await _keyStorage.getOrCreateDatabaseKey();
    final db = await _dbHelper.getDatabase(password);
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
    final password = await _keyStorage.getOrCreateDatabaseKey();
    final db = await _dbHelper.getDatabase(password);
    await db.delete(
      'exclusion_list',
      where: 'app_identifier = ?',
      whereArgs: [appIdentifier],
    );
  }
}

