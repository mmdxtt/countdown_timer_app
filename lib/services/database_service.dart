import 'package:sqflite/sqflite.dart';

import '../models/timer_record.dart';

/// 本地 SQLite 数据库服务（单例）。
class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  static const String _dbName = 'timer_records.db';
  static const String _table = 'timer_records';
  static const String _activeTable = 'active_task';

  Database? _db;

  Future<Database> get database async {
    _db ??= await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final dir = await getDatabasesPath();
    final path = '$dir/$_dbName';
    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            target_seconds INTEGER NOT NULL,
            effective_seconds INTEGER NOT NULL,
            completed_at_ms INTEGER NOT NULL,
            completion_type TEXT NOT NULL,
            category TEXT,
            sub_label TEXT
          )
        ''');
        await _createActiveTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE $_table ADD COLUMN category TEXT');
          await db.execute('ALTER TABLE $_table ADD COLUMN sub_label TEXT');
          await _createActiveTable(db);
        }
      },
    );
  }

  Future<void> _createActiveTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_activeTable (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        status TEXT NOT NULL,
        target_seconds INTEGER NOT NULL,
        deadline_ms INTEGER,
        remaining_ms INTEGER,
        pause_count INTEGER NOT NULL,
        category TEXT,
        sub_label TEXT
      )
    ''');
  }

  Future<int> insertRecord(TimerRecord record) async {
    final db = await database;
    return db.insert(_table, record.toMap());
  }

  Future<List<TimerRecord>> getRecordsBetween(DateTime start, DateTime end) async {
    final db = await database;
    final rows = await db.query(
      _table,
      where: 'completed_at_ms >= ? AND completed_at_ms <= ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'completed_at_ms DESC',
    );
    return rows.map(TimerRecord.fromMap).toList();
  }

  Future<List<TimerRecord>> getAllRecords() async {
    final db = await database;
    final rows = await db.query(_table, orderBy: 'completed_at_ms DESC');
    return rows.map(TimerRecord.fromMap).toList();
  }

  Future<int> clearAll() async {
    final db = await database;
    return db.delete(_table);
  }

  // ---- 进行中任务 ----

  Future<void> saveActiveTask(ActiveTask task) async {
    final db = await database;
    await db.insert(
      _activeTable,
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearActiveTask() async {
    final db = await database;
    await db.delete(_activeTable);
  }

  Future<ActiveTask?> loadActiveTask() async {
    final db = await database;
    final rows = await db.query(_activeTable, limit: 1);
    if (rows.isEmpty) return null;
    return ActiveTask.fromMap(rows.first);
  }
}
