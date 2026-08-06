import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// Database helper managing the encrypted SQLite database via [sqflite_sqlcipher].
///
/// Implements all four tables specified in Architecture §3:
/// - history_entries
/// - exclusion_list
/// - settings
/// - audit_log
class DatabaseHelper {
  DatabaseHelper({
    this.customPath,
    this.databaseFactoryOverride,
  });

  final String? customPath;
  final DatabaseFactory? databaseFactoryOverride;
  Database? _db;

  /// Returns the open encrypted database instance, initializing it if necessary.
  Future<Database> getDatabase(String password) async {
    if (_db != null && _db!.isOpen) {
      return _db!;
    }
    _db = await initDatabase(password);
    return _db!;
  }

  /// Initializes the database with SQLCipher password protection.
  Future<Database> initDatabase(String password) async {
    final path = customPath ?? await _getDatabasePath();

    final dbFactory = databaseFactoryOverride;
    if (dbFactory != null) {
      return dbFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: _onCreate,
        ),
      );
    }

    try {
      return await openDatabase(
        path,
        password: password,
        version: 1,
        onCreate: _onCreate,
      );
    } on Object catch (_) {
      try {
        await deleteDatabase(path);
      } on Object catch (_) {}
      return openDatabase(
        path,
        password: password,
        version: 1,
        onCreate: _onCreate,
      );
    }
  }

  Future<String> _getDatabasePath() async {
    final docsDir = await getApplicationDocumentsDirectory();
    return p.join(docsDir.path, 'keyflow_encrypted.db');
  }

  /// Creates all 4 required tables per Architecture §3.
  Future<void> _onCreate(Database db, int version) async {
    // 1. history_entries
    await db.execute('''
      CREATE TABLE history_entries (
        id TEXT PRIMARY KEY,
        text TEXT NOT NULL,
        source_app TEXT NOT NULL,
        captured_at INTEGER NOT NULL,
        language TEXT,
        was_translated INTEGER NOT NULL DEFAULT 0,
        device_id TEXT,
        category TEXT,
        use_count INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Index for fast search and recency ordering
    await db.execute('''
      CREATE INDEX idx_history_captured_at ON history_entries(captured_at DESC)
    ''');

    // 2. exclusion_list
    await db.execute('''
      CREATE TABLE exclusion_list (
        app_identifier TEXT PRIMARY KEY,
        added_at INTEGER NOT NULL
      )
    ''');

    // 3. settings
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Default retention setting: 30 days
    await db.execute('''
      INSERT INTO settings (key, value) VALUES ('retention_days', '30')
    ''');

    // 4. audit_log
    await db.execute('''
      CREATE TABLE audit_log (
        id TEXT PRIMARY KEY,
        event_type TEXT NOT NULL,
        detail TEXT NOT NULL,
        occurred_at INTEGER NOT NULL
      )
    ''');
  }

  /// Closes the active database connection.
  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}
