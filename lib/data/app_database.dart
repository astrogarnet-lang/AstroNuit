import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final root = await getDatabasesPath();
    _db = await openDatabase(
      join(root, 'timecontrol.db'),
      version: 1,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE participants(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            first_name TEXT NOT NULL,
            last_name TEXT NOT NULL,
            phone TEXT NOT NULL DEFAULT '',
            role TEXT NOT NULL DEFAULT '',
            created_at INTEGER NOT NULL,
            archived INTEGER NOT NULL DEFAULT 0,
            deleted INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE work_sessions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            participant_id INTEGER NOT NULL,
            check_in INTEGER NOT NULL,
            check_out INTEGER,
            created_at INTEGER NOT NULL,
            FOREIGN KEY(participant_id) REFERENCES participants(id)
          )
        ''');
        await db.execute('''
          CREATE TABLE audit_log(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            entity_type TEXT NOT NULL,
            entity_id INTEGER NOT NULL,
            action TEXT NOT NULL,
            details TEXT NOT NULL DEFAULT '',
            created_at INTEGER NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_sessions_participant ON work_sessions(participant_id)');
        await db.execute('CREATE INDEX idx_sessions_checkin ON work_sessions(check_in)');
      },
    );
    return _db!;
  }

  Future<List<Map<String, dynamic>>> people({String search = '', bool archived = false}) async {
    final db = await database;
    final q = '%${search.trim()}%';
    return db.query('participants',
      where: 'deleted = 0 AND archived = ? AND (first_name LIKE ? OR last_name LIKE ? OR role LIKE ? OR phone LIKE ?)',
      whereArgs: [archived ? 1 : 0, q, q, q, q],
      orderBy: 'first_name COLLATE NOCASE, last_name COLLATE NOCASE');
  }

  Future<void> savePerson(Map<String, dynamic> p) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      if (p['id'] == null) {
        final id = await txn.insert('participants', {
          ...p, 'created_at': now,
        });
        await txn.insert('audit_log', {'entity_type':'participant','entity_id':id,'action':'created','created_at':now});
      } else {
        await txn.update('participants', p, where: 'id = ?', whereArgs: [p['id']]);
        await txn.insert('audit_log', {'entity_type':'participant','entity_id':p['id'],'action':'updated','created_at':now});
      }
    });
  }

  Future<void> archivePerson(int id, bool archive) async {
    final db = await database;
    await db.update('participants', {'archived': archive ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
    await db.insert('audit_log', {'entity_type':'participant','entity_id':id,'action':archive ? 'archived' : 'restored','created_at':DateTime.now().millisecondsSinceEpoch});
  }

  Future<void> softDeletePerson(int id) async {
    final db = await database;
    await db.update('participants', {'deleted': 1}, where: 'id = ?', whereArgs: [id]);
    await db.insert('audit_log', {'entity_type':'participant','entity_id':id,'action':'soft_deleted','created_at':DateTime.now().millisecondsSinceEpoch});
  }

  Future<List<Map<String, dynamic>>> openSessions() async {
    final db = await database;
    return db.rawQuery('''
      SELECT w.*, p.first_name, p.last_name FROM work_sessions w
      JOIN participants p ON p.id = w.participant_id
      WHERE w.check_out IS NULL AND p.deleted = 0 ORDER BY w.check_in DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> sessionsForDay(DateTime day) async {
    final db = await database;
    final start = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
    final end = DateTime(day.year, day.month, day.day + 1).millisecondsSinceEpoch;
    return db.rawQuery('''
      SELECT w.* FROM work_sessions w JOIN participants p ON p.id = w.participant_id
      WHERE p.deleted = 0 AND w.check_in < ? AND (w.check_out IS NULL OR w.check_out >= ?)
      ORDER BY w.check_in
    ''', [end, start]);
  }

  Future<void> checkIn(int participantId) async {
    final db = await database;
    await db.transaction((txn) async {
      final open = await txn.query('work_sessions', where: 'participant_id = ? AND check_out IS NULL', whereArgs: [participantId], limit: 1);
      if (open.isNotEmpty) throw Exception('У участника уже есть открытая рабочая сессия.');
      final now = DateTime.now().millisecondsSinceEpoch;
      final id = await txn.insert('work_sessions', {'participant_id':participantId,'check_in':now,'created_at':now});
      await txn.insert('audit_log', {'entity_type':'work_session','entity_id':id,'action':'check_in','created_at':now});
    });
  }

  Future<void> checkOut(int participantId) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query('work_sessions', where: 'participant_id = ? AND check_out IS NULL', whereArgs: [participantId], orderBy: 'check_in DESC', limit: 1);
      if (rows.isEmpty) throw Exception('Нет открытой рабочей сессии.');
      final now = DateTime.now().millisecondsSinceEpoch;
      final start = rows.first['check_in'] as int;
      if (now < start) throw Exception('Время ухода не может быть раньше прихода.');
      final id = rows.first['id'] as int;
      await txn.update('work_sessions', {'check_out':now}, where: 'id = ?', whereArgs: [id]);
      await txn.insert('audit_log', {'entity_type':'work_session','entity_id':id,'action':'check_out','created_at':now});
    });
  }

  Future<Map<String, dynamic>> summary() async {
    final db = await database;
    final people = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM participants WHERE deleted = 0 AND archived = 0')) ?? 0;
    final present = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(DISTINCT participant_id) FROM work_sessions WHERE check_out IS NULL')) ?? 0;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final end = DateTime(now.year, now.month, now.day + 1).millisecondsSinceEpoch;
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(
        MAX(0, MIN(COALESCE(check_out, ?), ?) - MAX(check_in, ?))
      ), 0) AS millis
      FROM work_sessions WHERE check_in < ? AND (check_out IS NULL OR check_out > ?)
    ''', [now.millisecondsSinceEpoch, end, start, end, start]);
    final millis = (rows.first['millis'] as num?)?.toInt() ?? 0;
    return {'people': people, 'present': present, 'todayHours': (millis / 3600000).toStringAsFixed(1)};
  }
}
