// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class L10nKo extends L10n {
  L10nKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'Mehh';

  @override
  String get keep => '킵';

  @override
  String get pile => '정리';

  @override
  String get toTrash => '휴지통으로';

  @override
  String get pileCancel => '정리 취소';

  @override
  String get back => '돌아가기';

  @override
  String get close => '닫기';

  @override
  String get home => '홈으로';

  @override
  String get settings => '설정';

  @override
  String get cancel => '취소';

  @override
  String get undo => '되돌리기';

  @override
  String get reset => '처음대로';

  @override
  String get retry => '다시 시도';

  @override
  String get loadingGroups => '사진을 묶는 중이에요';

  @override
  String get loadFailed => '사진을 불러오지 못했어요';

  @override
  String get noPhotos => '정리할 사진이 없어요';

  @override
  String groupsLeft(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '정리할 묶음\n$countString개 남았어요';
  }

  @override
  String get noGroupsLeft => '지금은\n정리할 묶음이 없어요';

  @override
  String get sectionOthers => '따로 보기';

  @override
  String get jumpToYear => '연도 이동';

  @override
  String freedThisMonth(String size) {
    return '이번 달 $size 비웠어요';
  }

  @override
  String photoTotal(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '사진 $countString장';
  }

  @override
  String analyzingPercent(int percent) {
    return '사진 살펴보는 중 $percent%';
  }

  @override
  String locatingPercent(int percent) {
    return '장소 확인 중 $percent%';
  }

  @override
  String get duplicatesFree => '무료로 정리';

  @override
  String duplicatesFound(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '똑같은 사진 $countString장 찾았어요';
  }

  @override
  String get review => '살펴보기';

  @override
  String photos(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString장';
  }

  @override
  String suggestedCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '정리 추천 $countString장';
  }

  @override
  String get analyzingShort => '살펴보는 중';

  @override
  String get allSeen => '다 봤어요';

  @override
  String get pickScreenshots => '지울 캡처를 골라 보세요';

  @override
  String get limitedAccess => '일부 사진만 허용했어요.\n전체를 허용하면 더 많이 찾을 수 있어요.';

  @override
  String get choosePhotos => '사진 고르기';

  @override
  String get screenshots => '캡처';

  @override
  String get singles => '한 장 사진';

  @override
  String get duplicatesTitle => '똑같은 사진';

  @override
  String get reasonSharp => '초점 선명';

  @override
  String get reasonExposure => '밝기 적당';

  @override
  String summaryJunk(int count) {
    return '실수로 찍힌 사진 $count장';
  }

  @override
  String summaryBlurry(int count) {
    return '더 선명한 컷이 있는 흔들린 사진 $count장';
  }

  @override
  String summaryBurst(int count) {
    return '비슷한 연속 컷 $count장';
  }

  @override
  String get summaryDuplicates => '묶음마다 하나만 남기고 똑같은 사진에 X를 쳐 뒀어요';

  @override
  String get tagBest => '베스트';

  @override
  String get tagBurst => '비슷한 컷';

  @override
  String get tagBlurry => '흔들림';

  @override
  String get tagJunk => '실수';

  @override
  String get tagOriginal => '남길 사진';

  @override
  String get tagDuplicate => '똑같은 사진';

  @override
  String noteBestWith(String reason) {
    return '베스트 · $reason';
  }

  @override
  String get noteBurst => '비슷한 연속 컷';

  @override
  String get noteBlurry => '더 선명한 컷이 있어요';

  @override
  String get noteJunk => '실수로 찍힌 것 같아요';

  @override
  String get noteKeeper => '남길 사진';

  @override
  String get sendToCortex => 'Cortex로 보내기';

  @override
  String get cortexSent => 'Cortex로 보냈어요 · 정리에 넣어 뒀어요';

  @override
  String get cortexFailed => 'Cortex로 보내지 못했어요';

  @override
  String get photoSemantics => '사진. 위로 밀면 정리, 아래로 밀면 킵';

  @override
  String get nextPhoto => '다음 사진';

  @override
  String get prevPhoto => '이전 사진';

  @override
  String get trashBarSemantics => '정리. 사진을 위로 올려도 돼요';

  @override
  String get markForRemoval => '정리하기';

  @override
  String get resetTitle => '처음 상태로 되돌릴까요?';

  @override
  String sceneLossTitle(int count) {
    return '$count개 장면은 사진이 하나도 안 남아요';
  }

  @override
  String get sceneLossBody => '비슷한 사진에 전부 X를 쳤어요. 그래도 휴지통으로 보낼까요?';

  @override
  String get lookAgain => '다시 볼게요';

  @override
  String get selectAll => '전체 선택';

  @override
  String get deselectAll => '선택 해제';

  @override
  String get markedPhoto => '정리할 사진';

  @override
  String get photo => '사진';

  @override
  String trashCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString장 휴지통으로';
  }

  @override
  String get analyzingTitle => '사진을 살펴보는 중이에요';

  @override
  String get analyzingDetail => '추천이 조금씩 채워져요.';

  @override
  String get noneFound => '정리할 사진을 못 찾았어요';

  @override
  String get willRemoveSuffix => ' 정리할게요';

  @override
  String countAndRange(String count, String range) {
    return '$count · $range';
  }

  @override
  String get trashFailed => '휴지통으로 보내지 못했어요. 사진은 그대로예요.';

  @override
  String trashed(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString장을 휴지통으로 보냈어요 · 갤러리 휴지통에서 30일 동안 되살릴 수 있어요';
  }

  @override
  String get clearTitle => '모든 기록을 지울까요?';

  @override
  String get clearBody => '사진 분석 결과, 킵·정리 기록, 비운 용량 기록을 지워요.\n사진은 지워지지 않아요.';

  @override
  String get clearConfirm => '지우기';

  @override
  String get cleared => '기록을 모두 지웠어요';

  @override
  String get privacyTitle => '사진과 기록은 이 폰에만 있어요';

  @override
  String get privacyLocal =>
      '사진 분석과 정리·킵 기록은 이 폰 안에만 저장돼요. 서버로 보내지 않고, 클라우드 백업에도 넣지 않아요.';

  @override
  String get privacyGeocode => '장소 이름을 찾을 때는 사진의 위치 좌표만 휴대폰의 위치 서비스로 보내요.';

  @override
  String get privacyTrash => '휴지통으로 보낸 사진은 30일 동안 갤러리 휴지통에서 되살릴 수 있어요.';

  @override
  String get clearAll => '모든 기록 지우기';

  @override
  String get onboardingTitle => '사진 정리,\n제가 먼저 해둘게요';

  @override
  String get onboardingBody =>
      '찍은 날짜와 장소로 사진을 묶고, 똑같은 사진을 찾으려면 사진 전체에 접근해야 해요.';

  @override
  String get promiseLocal => '사진과 기록은 폰 밖으로 나가지 않아요.';

  @override
  String get promiseLearn => '추천은 앱이 먼저 골라 둔 것일 뿐이에요. 언제든 바꿀 수 있어요.';

  @override
  String get promiseRestore => '휴지통으로 보낸 사진은 30일 동안 갤러리 휴지통에서 되살릴 수 있어요.';

  @override
  String get allowAccess => '사진 접근 허용';

  @override
  String get allowInSettings => '설정에서 허용하기';

  @override
  String get allKept => '전부 킵하기로 했어요';

  @override
  String unlockTitle(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '정리 추천 $countString장을 골라 뒀어요';
  }

  @override
  String get unlockHint => '직접 X를 눌러 고르는 건 무료예요';

  @override
  String get billingPending => '결제를 확인하는 중이에요';

  @override
  String get billingFailed => '결제를 마치지 못했어요';

  @override
  String get billingUnavailable => '지금은 스토어에 연결할 수 없어요';

  @override
  String get billingDemo => '미리보기라 실제로 결제되지 않아요';

  @override
  String unlockFree(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '무료로 보기 · 이번 달 $countString개 남음';
  }

  @override
  String get unlockPro => 'Pro로 모든 묶음 보기';

  @override
  String get proChip => 'Pro';

  @override
  String freeChip(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '무료 $countString개';
  }

  @override
  String get proTitle => 'Mehh Pro';

  @override
  String get proBody => '모든 묶음의 정리 추천을 바로 봐요.';

  @override
  String proFree(int limit, int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '무료로는 매달 묶음 $limit개까지 추천을 볼 수 있어요. 이번 달 $countString개 남았어요.';
  }

  @override
  String get proActive => 'Pro를 쓰고 있어요. 모든 묶음의 추천이 열려 있어요.';

  @override
  String get planLifetime => '평생 이용권';

  @override
  String get planLifetimeNote => '한 번 사면 계속 써요';

  @override
  String get planYearly => '1년 이용권';

  @override
  String get planYearlyNote => '매년 자동 갱신 · 언제든 해지';

  @override
  String get planBest => '추천';

  @override
  String get proNotes =>
      '회원 가입 없이 스토어 계정으로 사요. 폰을 바꾸거나 앱을 다시 깔아도 [구매 복원]으로 다시 쓸 수 있어요. 1년 이용권은 해지하지 않으면 매년 자동으로 결제되고, 스토어의 구독 메뉴에서 언제든 해지할 수 있어요.';

  @override
  String get restorePurchases => '구매 복원';

  @override
  String get restored => '구매를 복원했어요';

  @override
  String get nothingToRestore => '복원할 구매가 없어요';

  @override
  String get proThanks => 'Pro가 열렸어요';

  @override
  String proNudge(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString장 정리했어요. 남은 묶음도 추천대로 바로 정리해 볼까요?';
  }
}
