import 'package:flutter_test/flutter_test.dart';
import 'package:mehh/data/sqlite_store.dart';
import 'package:mehh/models/decision.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late String path;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    path = '${await getDatabasesPath()}/mehh.db';
    await deleteDatabase(path);
  });

  tearDown(() => deleteDatabase(path));

  Future<List<String>> tables() async {
    final db = await openDatabase(path, singleInstance: false);
    final rows = await db.query('sqlite_master', where: "type = 'table'");
    await db.close();
    return [for (final r in rows) r['name'] as String];
  }

  // v11 그대로: 앱이 쓰는 표들과 지울 decision_log
  Future<void> makeV11() async {
    final db = await openDatabase(
      path,
      version: 11,
      singleInstance: false,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE decisions (id TEXT PRIMARY KEY, state TEXT, at INTEGER, hold_at INTEGER)',
        );
        await db.execute(
          'CREATE TABLE decision_log (id TEXT, state TEXT, at INTEGER)',
        );
        for (final t in [
          'features',
          'freed',
          'picks',
          'seen',
          'cortex_sent',
          'faces',
          'names',
        ]) {
          await db.execute('CREATE TABLE $t (id TEXT)');
        }
        await db.execute(
          'CREATE TABLE counters (key TEXT PRIMARY KEY, value INTEGER)',
        );
      },
    );
    await db.insert('decisions', {
      'id': 'a',
      'state': DecisionState.toTrash.name,
      'at': 1000,
    });
    await db.insert('decision_log', {
      'id': 'a',
      'state': DecisionState.toTrash.name,
      'at': 1000,
    });
    await db.close();
  }

  test('v11에서 올라오면 decision_log만 사라지고 결정은 남는다 (리뷰 11-01 S-4)', () async {
    await makeV11();
    expect(await tables(), contains('decision_log'));

    final store = SqliteStore();
    final d = await store.loadDecisions();
    expect(d['a']?.state, DecisionState.toTrash);
    expect(await tables(), isNot(contains('decision_log')));

    // 올라온 뒤에도 저장·전부 지우기가 된다
    await store.saveDecisions([
      Decision(photoId: 'b', state: DecisionState.keep, at: DateTime(2026)),
    ]);
    expect((await store.loadDecisions()).keys, containsAll(['a', 'b']));
    await store.clearAll();
    expect(await store.loadDecisions(), isEmpty);
  });

  test('새로 설치하면 decision_log가 없고 결정을 저장·다시 읽는다 (리뷰 11-01 S-4)', () async {
    await SqliteStore().saveDecisions([
      Decision(photoId: 'a', state: DecisionState.toTrash, at: DateTime(2026)),
    ]);
    expect(await tables(), isNot(contains('decision_log')));
    // 앱을 다시 켠 것처럼 새 저장소로 읽는다
    expect(
      (await SqliteStore().loadDecisions())['a']?.state,
      DecisionState.toTrash,
    );
    await SqliteStore().clearAll();
  });
  // 1.17.2(6cdd557, 비공개 테스트 첫 빌드) onCreate 그대로: decision_log·views 있음, names에 photos 없음
  Future<void> makeV9() async {
    final db = await openDatabase(
      path,
      version: 9,
      singleInstance: false,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE features (
            id TEXT PRIMARY KEY, hi INTEGER, lo INTEGER,
            sharp REAL, bright REAL, contrast REAL, text REAL, mod INTEGER, v INTEGER)''');
        await db.execute(
          'CREATE TABLE decisions (id TEXT PRIMARY KEY, state TEXT, at INTEGER, hold_at INTEGER)',
        );
        await db.execute(
          'CREATE TABLE decision_log (id TEXT, state TEXT, at INTEGER)',
        );
        await db.execute(
          'CREATE TABLE views (id TEXT PRIMARY KEY, count INTEGER, last_at INTEGER)',
        );
        await db.execute(
          'CREATE TABLE freed (month TEXT PRIMARY KEY, bytes INTEGER)',
        );
        await db.execute(
          'CREATE TABLE picks (at INTEGER, kind TEXT, tag TEXT, suggested INTEGER, sent INTEGER)',
        );
        await db.execute('CREATE TABLE seen (id TEXT PRIMARY KEY)');
        await db.execute(
          'CREATE TABLE cortex_sent (id TEXT PRIMARY KEY, at INTEGER, got INTEGER DEFAULT 0)',
        );
        await db.execute(
          'CREATE TABLE counters (key TEXT PRIMARY KEY, n INTEGER)',
        );
        await db.execute(
          'CREATE TABLE faces (id TEXT PRIMARY KEY, closed INTEGER)',
        );
        await db.execute(
          'CREATE TABLE names (id TEXT PRIMARY KEY, name TEXT)',
        );
      },
    );
    await db.insert('decisions', {
      'id': 'a',
      'state': DecisionState.keep.name,
      'at': 1000,
    });
    await db.insert('names', {'id': 'day-1', 'name': '롯데월드'});
    await db.insert('cortex_sent', {'id': 'c', 'at': 1000, 'got': 1});
    await db.insert('counters', {'key': 'closedTest', 'n': 1});
    await db.close();
  }

  test('비공개 테스트 첫 빌드(v9)에서 올라와도 결정·이름·Cortex 기록·카운터가 남는다 (리뷰 11-06 S-1)', () async {
    await makeV9();
    expect(await tables(), containsAll(['decision_log', 'views']));

    final store = SqliteStore();
    expect((await store.loadDecisions())['a']?.state, DecisionState.keep);
    expect(await store.loadCortexSent(), {'c': true});
    expect(await store.counter('closedTest'), 1);
    // 옛 이름은 같은 묶음 id로, 사진 목록 없이 읽힌다
    final names = await store.loadNames();
    expect(names['day-1']?.name, '롯데월드');
    expect(names['day-1']?.photoIds, isEmpty);
    expect(await tables(), isNot(contains('views')));
    expect(await tables(), isNot(contains('decision_log')));

    // 올라온 뒤 사진 목록을 포함한 새 이름을 저장한다
    await store.saveName('day-2', '바다', photoIds: ['p1', 'p2']);
    expect((await store.loadNames())['day-2']?.photoIds, {'p1', 'p2'});
    await store.clearAll();
  });
}
