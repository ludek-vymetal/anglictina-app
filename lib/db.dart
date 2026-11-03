import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';
import 'srs.dart';

/// Všechna data jsou jen v telefonu (SQLite), funguje i bez signálu.
class Db {
  Db._();
  static final Db instance = Db._();
  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, 'anglictina.db'),
      version: 1,
      onCreate: (d, v) async {
        await d.execute('''
          CREATE TABLE rooms(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            image_path TEXT NOT NULL,
            width REAL NOT NULL,
            height REAL NOT NULL,
            created INTEGER NOT NULL
          )''');
        await d.execute('''
          CREATE TABLE words(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            room_id INTEGER NOT NULL,
            en TEXT NOT NULL,
            cs TEXT NOT NULL,
            pron TEXT,
            x REAL NOT NULL,
            y REAL NOT NULL,
            sentence_en TEXT,
            sentence_cs TEXT,
            due INTEGER NOT NULL,
            interval REAL NOT NULL,
            ease REAL NOT NULL,
            reps INTEGER NOT NULL,
            lapses INTEGER NOT NULL,
            created INTEGER NOT NULL
          )''');
        await d.execute(
            'CREATE TABLE kv(key TEXT PRIMARY KEY, value TEXT NOT NULL)');
      },
    );
    return _db!;
  }

  // ---------- místnosti ----------

  Future<int> addRoom(Room r) async => (await db).insert('rooms', r.toMap());

  Future<List<Room>> rooms() async {
    final rows = await (await db).query('rooms', orderBy: 'created ASC');
    return rows.map(Room.fromMap).toList();
  }

  Future<void> deleteRoom(int id) async {
    final d = await db;
    await d.delete('words', where: 'room_id = ?', whereArgs: [id]);
    await d.delete('rooms', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- slova ----------

  Future<int> addWord(Word w) async => (await db).insert('words', w.toMap());

  Future<void> updateWord(Word w) async => (await db)
      .update('words', w.toMap(), where: 'id = ?', whereArgs: [w.id]);

  Future<void> deleteWord(int id) async =>
      (await db).delete('words', where: 'id = ?', whereArgs: [id]);

  Future<List<Word>> wordsInRoom(int roomId) async {
    final rows = await (await db).query('words',
        where: 'room_id = ?', whereArgs: [roomId], orderBy: 'id ASC');
    return rows.map(Word.fromMap).toList();
  }

  Future<Word?> word(int id) async {
    final rows =
        await (await db).query('words', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Word.fromMap(rows.first);
  }

  /// Slova k opakování teď: nejdřív ta, co jsou na řadě, pak nová
  /// (max [Srs.newPerDay] nových denně).
  Future<List<Word>> dueQueue({int? roomId}) async {
    final d = await db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final roomFilter = roomId == null ? '' : ' AND room_id = $roomId';
    final due = await d.query('words',
        where: '(reps > 0 OR lapses > 0) AND due <= ?$roomFilter',
        whereArgs: [now],
        orderBy: 'due ASC');
    final left = Srs.newPerDay - await newIntroducedToday();
    final fresh = left <= 0
        ? <Map<String, Object?>>[]
        : await d.query('words',
            where: 'reps = 0 AND lapses = 0$roomFilter',
            orderBy: 'room_id ASC, id ASC',
            limit: left);
    return [...due, ...fresh].map(Word.fromMap).toList();
  }

  Future<Map<String, int>> stats() async {
    final d = await db;
    final now = DateTime.now().millisecondsSinceEpoch;
    int count(List<Map<String, Object?>> r) => (r.first['c'] as int?) ?? 0;
    final total = count(await d.rawQuery('SELECT COUNT(*) c FROM words'));
    final learned = count(await d
        .rawQuery('SELECT COUNT(*) c FROM words WHERE interval >= 7'));
    final due = count(await d.rawQuery(
        'SELECT COUNT(*) c FROM words WHERE (reps > 0 OR lapses > 0) AND due <= ?',
        [now]));
    final fresh = count(await d.rawQuery(
        'SELECT COUNT(*) c FROM words WHERE reps = 0 AND lapses = 0'));
    final left = (Srs.newPerDay - await newIntroducedToday()).clamp(0, 999);
    return {
      'total': total,
      'learned': learned,
      'due': due,
      'newToday': fresh < left ? fresh : left,
      'streak': await streak(),
    };
  }

  // ---------- denní počítadla ----------

  String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  Future<String?> _get(String k) async {
    final r = await (await db).query('kv', where: 'key = ?', whereArgs: [k]);
    return r.isEmpty ? null : r.first['value'] as String;
  }

  Future<void> _set(String k, String v) async => (await db).insert(
      'kv', {'key': k, 'value': v},
      conflictAlgorithm: ConflictAlgorithm.replace);

  Future<int> newIntroducedToday() async {
    if (await _get('new_date') != _today()) return 0;
    return int.tryParse(await _get('new_count') ?? '0') ?? 0;
  }

  Future<void> markNewIntroduced() async {
    final c = await newIntroducedToday();
    await _set('new_date', _today());
    await _set('new_count', '${c + 1}');
  }

  /// Série dnů v řadě, kdy jsi aspoň chvíli opakoval.
  Future<int> streak() async {
    final last = await _get('streak_date');
    final n = int.tryParse(await _get('streak') ?? '0') ?? 0;
    if (last == null) return 0;
    final y = DateTime.now().subtract(const Duration(days: 1));
    final yesterday = '${y.year}-${y.month}-${y.day}';
    return (last == _today() || last == yesterday) ? n : 0;
  }

  Future<void> markPracticed() async {
    final last = await _get('streak_date');
    if (last == _today()) return;
    final s = await streak();
    await _set('streak', '${s + 1}');
    await _set('streak_date', _today());
  }
}
