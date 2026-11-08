import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mehh/config/app_config.dart';
import 'package:mehh/l10n/app_localizations.dart';

/// 설정의 개인정보 문구는 첫 화면처럼 "정리 기록"이라고 한다. 처리방침의 오류 "기록"과 섞이지 않게 (S-1 2026-11-03)
void main() {
  test('Pro 안내의 무료 할 일: 영어 1장은 단수 (리뷰 11-08 S-3)', () {
    final en = lookupL10n(const Locale('en'));
    expect(en.freeTodoShots(1), 'Free right now: see 1 screenshot pick ›');
    expect(en.freeTodoDuplicates(1), 'Free right now: see 1 exact duplicate ›');
    expect(en.freeTodoShots(3), contains('3 screenshot picks'));
    expect(en.freeTodoDuplicates(3), contains('3 exact duplicates'));
    final ko = lookupL10n(const Locale('ko'));
    expect(ko.freeTodoShots(1), '지금 무료로: 캡처 추천 1장 보기 ›');
  });

  test('Cortex가 빈 목록을 보내면 한국어도 "0장" 대신 "받은 사진이 없다고" (UX-113)', () {
    final ko = lookupL10n(const Locale('ko'));
    expect(ko.cortexPartial(0), contains('받은 사진이 없다고'));
    expect(ko.cortexPartial(0), isNot(contains('0장')));
    expect(ko.cortexPartial(3), contains('3장만'));
  });

  test('설정 개인정보 제목·첫 줄은 두 언어 모두 정리 기록을 말한다', () {
    final ko = lookupL10n(const Locale('ko'));
    final en = lookupL10n(const Locale('en'));
    for (final s in [ko.privacyTitle, ko.privacyShortLocal]) {
      expect(s, contains('정리 기록'));
    }
    for (final s in [en.privacyTitle, en.privacyShortLocal]) {
      expect(s, contains('cleanup records'));
    }
  });

  test('영어 폰은 약관·처리방침을 영어 부분(#en)부터 연다 (UX-108)', () {
    expect(webDocUrl(termsUrl, 'ko'), termsUrl);
    expect(webDocUrl(termsUrl, 'en'), '$termsUrl#en');
    expect(webDocUrl(privacyPolicyUrl, 'en'), '$privacyPolicyUrl#en');
  });

  test('영어 Pro 안내의 무료 줄은 홈과 같은 종류 이름 (UX-109)', () {
    final en = lookupL10n(const Locale('en'));
    for (final name in [en.singles, en.duplicatesTitle]) {
      expect(en.proFreeKinds.toLowerCase(), contains(name.toLowerCase()));
    }
  });
  test('영어 첫 삭제 알림은 30일 동안 "되돌릴 수 있다"로 읽힌다 (UX-116)', () {
    final en = lookupL10n(const Locale('en'));
    for (final n in [1, 3]) {
      for (final s in [
        en.trashed(n, '2 MB'),
        en.trashedVideos(n, '2 MB'),
        en.proNudge(n),
      ]) {
        expect(s, contains('You can restore'));
        expect(s, isNot(contains('within 30 days, or')));
      }
    }
  });
}
