import 'package:sqflite/sqflite.dart';

import '../models/decision.dart';
import '../models/features.dart';
import '../models/pick.dart';
import 'store.dart';

/// 분석 방식이 바뀌면 올린다. 다른 버전의 분석 결과는 다시 계산한다.
const featuresVersion = 3;

const _featuresTable = '''
  CREATE TABLE features (
    id TEXT PRIMARY KEY, hi INTEGER, lo INTEGER,
    sharp REAL, bright REAL, contrast REAL, text REAL, mod INTEGER, v INTEGER)''';

const _picksTable = '''
  CREATE TABLE picks (
    at INTEGER, kind TEXT, tag TEXT, suggested INTEGER, sent INTEGER)''';

const _seenTable = 'CREATE TABLE seen (id TEXT PRIMARY KEY)';
const _cortexSentTable =
    'CREATE TABLE cortex_sent (id TEXT PRIMARY KEY, at INTEGER)';

class SqliteStore implements Store {
  Database? _db;

  Future<Database> get _database async => _db ??= await openDatabase(
    'mehh.db',
    version: 6,
    onUpgrade: (db, from, _) async {
      // 분석 결과는 캐시라서 버리고 다시 계산한다
      if (from < 3) {
        await db.execute('DROP TABLE IF EXISTS features');
        await db.execute(_featuresTable);
      }
      if (from < 4) await db.execute(_picksTable);
      if (from < 5) await db.execute(_seenTable);
      if (from < 6) await db.execute(_cortexSentTable);
    },
    onCreate: (db, _) async {
      await db.execute(_featuresTable);
      await db.execute('''
        CREATE TABLE decisions (
          id TEXT PRIMARY KEY, state TEXT, at INTEGER, hold_at INTEGER)''');
      await db.execute('''
        CREATE TABLE decision_log (
          id TEXT, state TEXT, at INTEGER)''');
      await db.execute('''
        CREATE TABLE views (
          id TEXT PRIMARY KEY, count INTEGER, last_at INTEGER)''');
      await db.execute('''
        CREATE TABLE freed (month TEXT PRIMARY KEY, bytes INTEGER)''');
      await db.execute(_picksTable);
      await db.execute(_seenTable);
      await db.execute(_cortexSentTable);
    },
  );

  @override
  Future<Map<String, PhotoFeatures>> loadFeatures() async {
    final rows = await (await _database).query(
      'features',
      where: 'v = ?',
      whereArgs: [featuresVersion],
    );
    return {
      for (final r in rows)
        r['id'] as String: PhotoFeatures(
          id: r['id'] as String,
          hashHi: r['hi'] as int,
          hashLo: r['lo'] as int,
          sharpness: (r['sharp'] as num).toDouble(),
          brightness: (r['bright'] as num).toDouble(),
          contrast: (r['contrast'] as num?)?.toDouble() ?? 50,
          textScore: (r['text'] as num?)?.toDouble() ?? 0,
          modifiedAt: r['mod'] as int,
        ),
    };
  }

  @override
  Future<void> saveFeatures(List<PhotoFeatures> list) async {
    final batch = (await _database).batch();
    for (final f in list) {
      batch.insert('features', {
        'id': f.id,
        'hi': f.hashHi,
        'lo': f.hashLo,
        'sharp': f.sharpness,
        'bright': f.brightness,
        'contrast': f.contrast,
        'text': f.textScore,
        'mod': f.modifiedAt,
        'v': featuresVersion,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<Map<String, Decision>> loadDecisions() async {
    final rows = await (await _database).query('decisions');
    return {
      for (final r in rows)
        r['id'] as String: Decision(
          photoId: r['id'] as String,
          state: DecisionState.values.byName(r['state'] as String),
          at: DateTime.fromMillisecondsSinceEpoch(r['at'] as int),
          holdAt: r['hold_at'] == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(r['hold_at'] as int),
        ),
    };
  }

  @override
  Future<void> saveDecisions(List<Decision> list) async {
    final batch = (await _database).batch();
    for (final d in list) {
      batch.insert('decisions', {
        'id': d.photoId,
        'state': d.state.name,
        'at': d.at.millisecondsSinceEpoch,
        'hold_at': d.holdAt?.millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      batch.insert('decision_log', {
        'id': d.photoId,
        'state': d.state.name,
        'at': d.at.millisecondsSinceEpoch,
      });
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<Map<String, ViewRecord>> loadViews() async {
    final rows = await (await _database).query('views');
    return {
      for (final r in rows)
        r['id'] as String: ViewRecord(
          count: r['count'] as int,
          lastAt: DateTime.fromMillisecondsSinceEpoch(r['last_at'] as int),
        ),
    };
  }

  // UPSERT 문법은 안드로이드 10 이하 SQLite에 없어서 UPDATE 후 없으면 INSERT.

  @override
  Future<void> recordView(String photoId, DateTime at) async {
    final ms = at.millisecondsSinceEpoch;
    await (await _database).transaction((tx) async {
      final n = await tx.rawUpdate(
        'UPDATE views SET count = count + 1, last_at = ? WHERE id = ?',
        [ms, photoId],
      );
      if (n == 0) {
        await tx.insert('views', {'id': photoId, 'count': 1, 'last_at': ms});
      }
    });
  }

  @override
  Future<void> addFreedBytes(String month, int bytes) async {
    await (await _database).transaction((tx) async {
      final n = await tx.rawUpdate(
        'UPDATE freed SET bytes = bytes + ? WHERE month = ?',
        [bytes, month],
      );
      if (n == 0) await tx.insert('freed', {'month': month, 'bytes': bytes});
    });
  }

  @override
  Future<int> freedBytes(String month) async {
    final rows = await (await _database).query(
      'freed',
      where: 'month = ?',
      whereArgs: [month],
    );
    return rows.isEmpty ? 0 : rows.first['bytes'] as int;
  }

  @override
  Future<void> addPicks(List<PickRecord> list) async {
    final batch = (await _database).batch();
    for (final p in list) {
      batch.insert('picks', {
        'at': p.at.millisecondsSinceEpoch,
        'kind': p.kind,
        'tag': p.tag,
        'suggested': p.suggested ? 1 : 0,
        'sent': p.sent ? 1 : 0,
      });
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<List<PickRecord>> loadPicks() async => [
    for (final r in await (await _database).query('picks'))
      PickRecord(
        at: DateTime.fromMillisecondsSinceEpoch(r['at'] as int),
        kind: r['kind'] as String,
        tag: r['tag'] as String?,
        suggested: r['suggested'] == 1,
        sent: r['sent'] == 1,
      ),
  ];

  @override
  Future<void> addSeen(Iterable<String> photoIds) async {
    final batch = (await _database).batch();
    for (final id in photoIds) {
      batch.insert('seen', {
        'id': id,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<Set<String>> loadSeen() async => {
    for (final r in await (await _database).query('seen')) r['id'] as String,
  };

  @override
  Future<void> addCortexSent(Iterable<String> photoIds) async {
    final batch = (await _database).batch();
    final at = DateTime.now().millisecondsSinceEpoch;
    for (final id in photoIds) {
      batch.insert('cortex_sent', {
        'id': id,
        'at': at,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> removeCortexSent(Iterable<String> photoIds) async {
    final batch = (await _database).batch();
    for (final id in photoIds) {
      batch.delete('cortex_sent', where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<Set<String>> loadCortexSent() async => {
    for (final r in await (await _database).query('cortex_sent'))
      r['id'] as String,
  };

  @override
  Future<void> clearAll() async {
    final db = await _database;
    await db.transaction((tx) async {
      for (final t in [
        'features',
        'decisions',
        'decision_log',
        'views',
        'freed',
        'picks',
        'seen',
        'cortex_sent',
      ]) {
        await tx.delete(t);
      }
    });
  }
}
