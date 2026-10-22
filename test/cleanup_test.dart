import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mehh/logic/duplicates.dart';
import 'package:mehh/logic/image_analysis.dart';
import 'package:mehh/logic/recommend.dart';
import 'package:mehh/models/decision.dart';
import 'package:mehh/models/features.dart';
import 'package:mehh/models/photo_meta.dart';

PhotoMeta meta(
  String id,
  DateTime t, {
  int w = 4000,
  int h = 3000,
  bool shot = false,
}) => PhotoMeta(id: id, takenAt: t, width: w, height: h, isScreenshot: shot);

PhotoFeatures feat(
  String id, {
  int hi = 0x12345678,
  int lo = 0x0F0F0F0F,
  double sharp = 500,
  double bright = 120,
}) => PhotoFeatures(
  id: id,
  hashHi: hi,
  hashLo: lo,
  sharpness: sharp,
  brightness: bright,
);

final t0 = DateTime(2026, 10, 3, 13);

void main() {
  group('완전 중복', () {
    test('다른 날 다시 저장한 사진은 중복, 해상도 큰 것을 남긴다', () {
      final photos = [
        meta('orig', t0),
        meta('kakao', t0.add(const Duration(days: 2)), w: 2000, h: 1500),
      ];
      final f = {
        'orig': feat('orig'),
        'kakao': feat('kakao', lo: 0x0F0F0F0E), // 1비트 차이
      };
      final sets = findDuplicates(photos, f);
      expect(sets.single.keep.id, 'orig');
      expect(sets.single.remove.single.id, 'kakao');
    });

    test('연속 촬영처럼 보이면 파일 크기가 같을 때만 중복', () {
      final photos = [
        meta('a', t0),
        meta('b', t0.add(const Duration(seconds: 2))),
      ];
      final f = {'a': feat('a'), 'b': feat('b')};
      expect(idsNeedingSize(photos, f), {'a', 'b'});
      expect(findDuplicates(photos, f), isEmpty);
      expect(findDuplicates(photos, f, sizes: {'a': 10, 'b': 11}), isEmpty);
      final same = findDuplicates(photos, f, sizes: {'a': 10, 'b': 10});
      expect(same.single.keep.id, 'a'); // 같은 해상도면 먼저 찍힌 것
    });

    test('스크린샷은 항상 파일 크기까지 확인', () {
      final photos = [
        meta('s1', t0, w: 1080, h: 2340, shot: true),
        meta(
          's2',
          t0.add(const Duration(days: 5)),
          w: 1080,
          h: 2340,
          shot: true,
        ),
      ];
      final f = {'s1': feat('s1'), 's2': feat('s2')};
      expect(findDuplicates(photos, f), isEmpty);
    });

    test('글자 많은 사진(예: 택시 내역)은 파일 크기까지 같아야 중복', () {
      final photos = [
        meta('r1', t0, w: 1080, h: 2340),
        meta('r2', t0.add(const Duration(days: 3)), w: 1080, h: 2340),
      ];
      PhotoFeatures receipt(String id) => PhotoFeatures(
        id: id,
        hashHi: 7,
        hashLo: 9,
        sharpness: 900,
        brightness: 230,
        textScore: 0.6,
      );
      final f = {'r1': receipt('r1'), 'r2': receipt('r2')};
      expect(findDuplicates(photos, f, sizes: {'r1': 100, 'r2': 120}), isEmpty);
      expect(
        findDuplicates(photos, f, sizes: {'r1': 100, 'r2': 100}),
        hasLength(1),
      );
    });

    test('해밍 거리 3 이상이거나 비율이 다르면 중복 아님', () {
      final photos = [
        meta('a', t0),
        meta('b', t0.add(const Duration(days: 1))),
        meta('c', t0.add(const Duration(days: 2)), w: 3000, h: 3000),
      ];
      final f = {
        'a': feat('a'),
        'b': feat('b', lo: 0x0F0F0F08), // 3비트 차이
        'c': feat('c'),
      };
      expect(findDuplicates(photos, f), isEmpty);
    });
  });

  group('연속 컷과 추천', () {
    test('60초 안 + 비슷하면 연속 컷, 가장 선명한 사진이 베스트', () {
      final photos = [
        meta('a', t0),
        meta('b', t0.add(const Duration(seconds: 20))),
        meta('c', t0.add(const Duration(seconds: 50))),
        meta('d', t0.add(const Duration(minutes: 5))),
      ];
      final f = {
        'a': feat('a', sharp: 300),
        'b': feat('b', sharp: 900, lo: 0x0F0F0F00),
        'c': feat('c', sharp: 5), // 흔들림
        'd': feat('d'),
      };
      final plan = planGroup(photos, f, {});
      expect(plan.bursts.map((b) => b.length), [3, 1]);
      expect(plan.best, {'b'});
      expect(plan.trash, {'a': TrashReason.burst, 'c': TrashReason.blurry});
      expect(plan.count(TrashReason.blurry), 1);
      expect(plan.count(TrashReason.burst), 1);
    });

    test('베스트를 정리 줄에 넣으면 남은 사진 중 베스트를 다시 골라 하나는 남긴다', () {
      final photos = [
        meta('a', t0),
        meta('b', t0.add(const Duration(seconds: 10))),
        meta('c', t0.add(const Duration(seconds: 20))),
      ];
      final f = {
        'a': feat('a', sharp: 300),
        'b': feat('b', sharp: 900),
        'c': feat('c', sharp: 500),
      };
      final plan = planGroup(photos, f, {
        'b': Decision(photoId: 'b', state: DecisionState.toTrash, at: t0),
      });
      expect(plan.best, {'c'}); // b 다음으로 선명한 c
      // 정리 줄에 넣은 b도 추천으로 남는다 (X를 쳐도 추천에서 빠지지 않는다)
      expect(plan.trash.keys, unorderedEquals(['a', 'b']));
    });

    test('중복 원본을 정리하면 다음 사진이 남길 사진이 된다', () {
      final s = DuplicateSet(meta('orig', t0), [
        meta('copy1', t0.add(const Duration(days: 1))),
        meta('copy2', t0.add(const Duration(days: 2))),
      ]);
      expect(keeperOf(s, (_) => false), 'orig');
      expect(keeperOf(s, (id) => id == 'orig'), 'copy1');
      expect(keeperOf(s, (_) => true), isNull);
    });

    test('[추천 보기]로 X(정리)가 된 추천은 이유와 함께 그대로 추천으로 남는다', () {
      final photos = [
        meta('a', t0),
        meta('b', t0.add(const Duration(seconds: 20))),
        meta('c', t0.add(const Duration(seconds: 50))),
      ];
      final f = {
        'a': feat('a', sharp: 300),
        'b': feat('b', sharp: 900),
        'c': feat('c', sharp: 5),
      };
      final before = planGroup(photos, f, {});
      final after = planGroup(photos, f, {
        for (final id in before.trash.keys)
          id: Decision(photoId: id, state: DecisionState.toTrash, at: t0),
      });
      expect(after.trash, before.trash);
      expect(after.best, before.best);
    });

    test('캡처: 연달아 찍은 같은 화면은 마지막 한 장만, 90일 넘은 캡처는 추천', () {
      final now = DateTime(2026, 10, 22);
      final shots = [
        meta('old', DateTime(2026, 6, 1), shot: true),
        meta('a', t0, shot: true),
        meta('b', t0.add(const Duration(seconds: 5)), shot: true),
        meta('c', t0.add(const Duration(minutes: 30)), shot: true),
      ];
      final f = {
        'old': feat('old', hi: 1),
        'a': feat('a'),
        'b': feat('b'),
        'c': feat('c', hi: 0x7FFFFFFF, lo: 0x7FFFFFFF),
      };
      final picks = planScreenshots(shots, f, {}, now: now);
      expect(picks, {'old': ShotReason.old, 'a': ShotReason.repeat});
      // 킵한 캡처는 빠진다
      final kept = planScreenshots(shots, f, {
        'old': Decision(photoId: 'old', state: DecisionState.keep, at: now),
      }, now: now);
      expect(kept.containsKey('old'), isFalse);
    });

    test('꺼 둔 이유(취향 학습)는 추천에서 빠진다', () {
      final photos = [
        meta('a', t0),
        meta('b', t0.add(const Duration(seconds: 20))),
        meta('c', t0.add(const Duration(seconds: 50))),
      ];
      final f = {
        'a': feat('a', sharp: 300),
        'b': feat('b', sharp: 900),
        'c': feat('c', sharp: 5),
      };
      final plan = planGroup(photos, f, {}, muted: {TrashReason.blurry});
      expect(plan.trash, {'a': TrashReason.burst});
    });

    test('킵한 사진은 추천에서 빠진다', () {
      final photos = [
        meta('a', t0),
        meta('b', t0.add(const Duration(seconds: 10))),
      ];
      final f = {'a': feat('a', sharp: 100), 'b': feat('b', sharp: 900)};
      final plan = planGroup(photos, f, {
        'a': Decision(photoId: 'a', state: DecisionState.keep, at: t0),
      });
      expect(plan.trash, isEmpty);
    });

    test('까만 사진은 한 장뿐이어도 정리 추천', () {
      final plan = planGroup([meta('a', t0)], {'a': feat('a', bright: 3)}, {});
      expect(plan.trash, {'a': TrashReason.junk});
    });

    test('주머니 속 사진 (어둡고 한 가지 색이고 흐림)은 정리 추천', () {
      final pocket = PhotoFeatures(
        id: 'p',
        hashHi: 1,
        hashLo: 2,
        sharpness: 8,
        brightness: 30,
        contrast: 5,
      );
      final plan = planGroup([meta('p', t0)], {'p': pocket}, {});
      expect(plan.trash, {'p': TrashReason.junk});
    });

    test('그 순간의 유일한 사진은 흔들렸어도 건드리지 않는다', () {
      final plan = planGroup([meta('a', t0)], {'a': feat('a', sharp: 3)}, {});
      expect(plan.trash, isEmpty);
    });

    test('어두운 밤 사진이라도 대비가 있으면 실수 사진이 아니다', () {
      final night = PhotoFeatures(
        id: 'n',
        hashHi: 1,
        hashLo: 2,
        sharpness: 30,
        brightness: 30,
        contrast: 40,
      );
      expect(planGroup([meta('n', t0)], {'n': night}, {}).trash, isEmpty);
    });
  });

  group('이미지 분석', () {
    Uint8List jpg(img.Image im) => Uint8List.fromList(img.encodeJpg(im));

    img.Image checker() {
      final im = img.Image(width: 128, height: 128);
      for (final p in im) {
        final on = ((p.x ~/ 8) + (p.y ~/ 8)).isEven;
        p.setRgb(on ? 230 : 20, on ? 230 : 20, on ? 230 : 20);
      }
      return im;
    }

    test('흐리게 하면 선명도가 크게 떨어지고, 재압축해도 해시는 거의 같다', () {
      final sharp = analyzeImage('s', jpg(checker()))!;
      final blurred = analyzeImage(
        'b',
        jpg(img.gaussianBlur(checker(), radius: 6)),
      )!;
      expect(blurred.sharpness, lessThan(sharp.sharpness / 5));

      final recompressed = analyzeImage(
        'r',
        Uint8List.fromList(img.encodeJpg(checker(), quality: 40)),
      )!;
      expect(sharp.hammingTo(recompressed), lessThanOrEqualTo(2));
    });

    test('글자 화면은 글자 점수가 높고, 사진 같은 화면은 낮다', () {
      // 흰 바탕에 검은 짧은 막대 줄 (글자 줄처럼)
      final text = img.Image(width: 128, height: 128);
      img.fill(text, color: img.ColorRgb8(255, 255, 255));
      for (var y = 8; y < 120; y += 10) {
        for (var x = 6; x < 120; x += 7) {
          img.fillRect(
            text,
            x1: x,
            y1: y,
            x2: x + 3,
            y2: y + 4,
            color: img.ColorRgb8(20, 20, 20),
          );
        }
      }
      expect(analyzeImage('t', jpg(text))!.textScore, greaterThan(0.2));

      // 부드러운 그라데이션 사진
      final photo = img.Image(width: 128, height: 128);
      for (final p in photo) {
        p.setRgb(p.x * 2, 80 + p.y, 120);
      }
      expect(analyzeImage('p', jpg(photo))!.textScore, lessThan(0.2));
    });

    test('까만 사진은 밝기가 낮다', () {
      final black = img.Image(width: 64, height: 64);
      expect(analyzeImage('k', jpg(black))!.brightness, lessThan(5));
    });
  });
}
