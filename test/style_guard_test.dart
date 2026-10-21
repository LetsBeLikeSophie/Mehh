import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 통일감 지키기 (CLAUDE.md): 화면 코드(lib/ui)에 글자 크기·모서리·색 숫자를 직접 쓰지 않는다.
/// 필요한 값이 없으면 lib/theme.dart에 토큰을 먼저 추가한다.
void main() {
  test('lib/ui에 글자 크기·모서리·색 숫자가 없다', () {
    final banned = {
      'fontSize: 숫자': RegExp(r'fontSize:\s*\d'),
      'circular(숫자)': RegExp(r'circular\(\s*\d'),
      'Color(0x…)': RegExp(r'Color\(0x'),
    };
    final found = <String>[];
    for (final f in Directory('lib/ui').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        for (final e in banned.entries) {
          if (e.value.hasMatch(lines[i])) {
            found.add('${f.path}:${i + 1} ${e.key} → theme.dart 토큰을 쓰세요');
          }
        }
      }
    }
    expect(found, isEmpty, reason: found.join('\n'));
  });
}
