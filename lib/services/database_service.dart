import 'package:sqflite/sqflite.dart';

import '../models/timer_record.dart';

/// 本地 SQLite 数据库服务（单例）。
class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  static const String _dbName = 'timer_records.db';
  static const String _table = 'timer_records';

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
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            target_seconds INTEGER NOT NULL,
            effective_seconds INTEGER NOT NULL,
            completed_at_ms INTEGER NOT NULL,
            completion_type TEXT NOT NULL
          )
        ''');
      },
    );
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
}
