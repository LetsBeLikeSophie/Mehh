import 'package:flutter_test/flutter_test.dart';
import 'package:mehh/logic/video_edits.dart';
import 'package:mehh/models/photo_meta.dart';

/// 편집한 동영상과 원본 짝 (2026-11-07 Sophie). 이름·시각은 실제 폰에서 읽은 값을 본떴다
void main() {
  PhotoMeta v(
    String id,
    String name, {
    DateTime? at,
    bool other = true,
    String? from,
    DateTime? made,
  }) => PhotoMeta(
    id: id,
    takenAt: made ?? at ?? DateTime(2026, 11, 7),
    width: 1080,
    height: 1920,
    isVideo: true,
    fileName: name,
    capturedAt: at,
    fromOtherApp: other,
    editedFrom: from,
  );

  List<List<String>> ids(EditSets e) => [
    for (final s in e.sets) [for (final x in s) x.id],
  ];

  final t = DateTime(2021, 4, 26, 18, 22, 14);

  test('캡컷: 파일 안에 적힌 원본 id로 짝 (찍은 시각이 비어 있어도)', () {
    final e = findEditSets([
      v('637', '20261023_232859.mp4', at: DateTime(2026, 10, 23), other: false),
      v('703', 'lv_0_20261107041537.mp4', from: '637'),
    ]);
    expect(ids(e), [
      ['637', '703'],
    ]);
    expect(e.edited, {'703'});
  });

  test('삼성 편집기: 카메라 밖의 "이름_1"이 같은 시각(2분 안)의 "이름"과 짝', () {
    final e = findEditSets([
      v('350', 'Screen_Recording_20210426-182214_CPanho_.mp4', at: t),
      v('351', 'Screen_Recording_20210426-182214_CPanho__1.mp4', at: t),
      v('352', 'Screen_Recording_20210430-142444_C.mp4', at: t.add(const Duration(days: 4))),
      v('353', 'Screen_Recording_20210430-142444_C_1.mp4',
          at: t.add(const Duration(days: 4, seconds: 42))),
    ]);
    expect(ids(e), [
      ['352', '353'],
      ['350', '351'],
    ]);
    expect(e.edited, {'351', '353'});
  });

  test('원본을 지운 편집본끼리도 짝 (편집본을 다시 편집)', () {
    final at = DateTime(2021, 5, 20, 15, 51, 47);
    final e = findEditSets([
      v('618', 'kakaotalk_1621493504648_1_1.mp4', at: at),
      v('447', 'kakaotalk_1621493504648_1.mp4', at: at),
    ]);
    expect(ids(e), [
      ['447', '618'],
    ]);
    expect(e.edited, {'618'});
  });

  test('짝이 아닌 것: 인샷(원본 정보 없음), 카메라끼리 같은 초, 시각이 먼 같은 이름, 다른 폴더의 같은 이름 사본', () {
    final e = findEditSets([
      v('1', '20261023_232859.mp4', at: DateTime(2026, 10, 23), other: false),
      v('2', 'InShot_20261107_041908908.mp4'),
      v('3', '20210207_195114.mp4', at: t, other: false),
      v('4', '20210207_195114_01.mp4', at: t, other: false),
      v('5', 'clip.mp4', at: t),
      v('6', 'clip_1.mp4', at: t.add(const Duration(days: 1))),
      v('7', 'Screen_Recording_x.mp4', at: t),
      v('8', 'Screen_Recording_x.mp4', at: t),
      v('9', 'lv_0_1.mp4', from: 'gone'),
    ]);
    expect(e.sets, isEmpty);
  });
}
