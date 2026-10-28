import 'package:flutter_test/flutter_test.dart';
import 'package:mehh/config/app_config.dart';
import 'package:mehh/data/billing.dart';

void main() {
  // 결제를 켠 빌드(공개키가 들어감)는 정식 출시용이다. 그때 "비공개 테스트 동안 무료"가
  // 켜져 있으면 돈을 받으면서도 모든 묶음이 무료로 열린다 (2026-10-28 Sophie r7)
  test('결제를 켠 빌드에서는 비공개 테스트 무료가 꺼져 있다', () {
    if (playPublicKey.isEmpty) return; // 아직 결제를 켜지 않은 빌드(비공개 테스트)
    expect(
      closedTestFree,
      isFalse,
      reason: '정식 출시 전에 lib/config/app_config.dart의 closedTestFree를 false로',
    );
  });
}
