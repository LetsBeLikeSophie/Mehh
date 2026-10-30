import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 앱 전용 폴더에 저장하는 작은 JSON 캐시. 2단계에서 DB로 옮긴다.
class JsonCache {
  JsonCache(this.fileName);

  final String fileName;

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$fileName');
  }

  Future<Map<String, dynamic>> read() async {
    try {
      final f = await _file();
      if (!await f.exists()) return {};
      return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> delete() async {
    final f = await _file();
    if (await f.exists()) await f.delete();
  }

  /// 파일마다 쓰기를 줄 세운다: 겹쳐 쓰면 같은 .tmp에 두 번 써 파일이 깨질 수 있다 (리뷰 2026-10-30 S-2)
  static final _writing = <String, Future<void>>{};

  Future<void> write(Map<String, dynamic> data) {
    final next = (_writing[fileName] ?? Future.value())
        .catchError((_) {})
        .then((_) => _write(data));
    _writing[fileName] = next;
    return next;
  }

  Future<void> _write(Map<String, dynamic> data) async {
    final f = await _file();
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(data), flush: true);
    await tmp.rename(f.path);
  }
}
