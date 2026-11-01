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
}
