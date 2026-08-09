import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper({this.customPath, this.databaseFactoryOverride});

  final String? customPath;
  final DatabaseFactory? databaseFactoryOverride;
  Database? _db;

  Future<Database> getDatabase(String password) async {
    if (_db != null && _db!.isOpen) {
      return _db!;
    }
    _db = await initDatabase(password);
    return _db!;
  }

  Future<Database> initDatabase(String password) async {
    final path = customPath ?? await _getDatabasePath();

    final dbFactory = databaseFactoryOverride;
    if (dbFactory != null) {
      return dbFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(version: 1, onCreate: _onCreate),
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

  Future<void> _onCreate(Database db, int version) async {
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

    await db.execute('''
      CREATE INDEX idx_history_captured_at ON history_entries(captured_at DESC)
    ''');

    await db.execute('''
      CREATE TABLE exclusion_list (
        app_identifier TEXT PRIMARY KEY,
        added_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('''
      INSERT INTO settings (key, value) VALUES ('retention_days', '30')
    ''');

    await db.execute('''
      CREATE TABLE audit_log (
        id TEXT PRIMARY KEY,
        event_type TEXT NOT NULL,
        detail TEXT NOT NULL,
        occurred_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}
