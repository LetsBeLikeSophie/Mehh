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
    return '이번 달 휴지통으로 $size 보냈어요';
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

    return '추천 정리 $countString장';
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
  String get singles => '낱장 사진';

  @override
  String get duplicatesTitle => '똑같은 사진';

  @override
  String get reasonSharp => '초점 선명';

  @override
  String get reasonExposure => '밝기 적당';

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
  String sceneLossTitle(int count) {
    return '$count개 장면은 사진이 하나도 안 남아요';
  }

  @override
  String get sceneLossBody => '비슷한 사진을 전부 선택했어요. 그래도 휴지통으로 보낼까요?';

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
  String countAndRange(String count, String range) {
    return '$count · $range';
  }

  @override
  String get trashFailed => '휴지통으로 보내지 못했어요. 사진은 그대로예요.';

  @override
  String trashed(int count, String size) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '✓ $countString장 · $size 휴지통으로 보냈어요 · 30일 안에 되살릴 수 있고, 휴지통을 비우면 그만큼 공간이 생겨요';
  }

  @override
  String get clearTitle => '모든 기록을 지울까요?';

  @override
  String get clearBody =>
      '사진 분석 결과, 킵·정리 기록, 휴지통으로 보낸 용량 기록, 바꾼 묶음 이름, Cortex로 보낸 표시를 지워요.\n사진은 지워지지 않아요.';

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
      '찍은 날짜와 장소로 사진을 묶고, 똑같은 사진과 큰 동영상을 찾으려면 사진·동영상 전체에 접근해야 해요.';

  @override
  String get promiseLocal => '사진과 기록은 폰 밖으로 나가지 않아요.';

  @override
  String get promiseLearn => '추천은 앱이 먼저 골라 둔 것일 뿐이에요. 언제든 바꿀 수 있어요.';

  @override
  String get promiseRestore => '휴지통으로 보낸 사진은 30일 동안 갤러리 휴지통에서 되살릴 수 있어요.';

  @override
  String get allowAccess => '사진·동영상 접근 허용';

  @override
  String get allowInSettings => '설정에서 허용하기';

  @override
  String get billingPending => '결제를 확인하는 중이에요';

  @override
  String get billingFailed => '결제를 마치지 못했어요';

  @override
  String get billingUnavailable => '지금은 스토어에 연결할 수 없어요';

  @override
  String get billingDemo => '미리보기라 실제로 결제되지 않아요';

  @override
  String get proChip => 'Pro';

  @override
  String get proTitle => 'Mehh Pro';

  @override
  String get proBody => '모든 묶음의 추천 정리를 바로 봐요';

  @override
  String proFree(int limit, int count, String date) {
    return 'Pro 없이: 묶음 하나에 ◉ 1개 · 매달 $limit개 · $count개 남음 · $date 다시 채움';
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
      '회원 가입 없음 · 폰을 바꾸면 [구매 복원]\n1년 이용권은 매년 자동 결제 · 스토어에서 언제든 해지';

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

    return '$countString장을 휴지통으로 보냈어요 · 30일 안에 되살릴 수 있고, 휴지통을 비우면 공간이 생겨요. 남은 묶음도 추천을 바로 볼까요?';
  }

  @override
  String get contact => '문의하기';

  @override
  String contactSubject(String version) {
    return 'Mehh 문의 ($version)';
  }

  @override
  String contactNote(String email) {
    return '$email · 사진이나 기록은 저절로 보내지 않아요. 메일에 적은 것만 받아요.';
  }

  @override
  String get contactCopied => '메일 주소를 복사했어요';

  @override
  String get accTitle => '추천 정확도';

  @override
  String get accEmpty => '아직 기록이 없어요. 묶음을 정리하고 [휴지통으로]를 누르면 쌓여요.';

  @override
  String get accRate => '추천을 받아들인 비율';

  @override
  String accSends(int count) {
    return '$count번 휴지통으로 보냈어요';
  }

  @override
  String accAccepted(int count, int total) {
    return '앱이 추천한 $total장 중 $count장을 보냈어요';
  }

  @override
  String accAdded(int count) {
    return '앱이 놓쳐서 직접 고른 사진 $count장';
  }

  @override
  String get accBest => '베스트로 고른 사진을 남긴 비율';

  @override
  String get accByTag => '이유별';

  @override
  String accTagLine(int count, int total) {
    return '$count/$total장';
  }

  @override
  String get accNote => '이 기록은 이 폰에만 있어요. 그날의 묶음 비율이 80%를 넘으면 결제를 켤 만해요.';

  @override
  String get cortexMultiUnsupported =>
      'Cortex가 아직 여러 장 받기를 못 해요. Cortex를 업데이트해 주세요.';

  @override
  String showPicks(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '추천 보기 · $countString장';
  }

  @override
  String get keepBarSemantics => '킵. 사진을 아래로 내려도 돼요';

  @override
  String get lookingAtPhotos => '사진을\n살펴보고 있어요';

  @override
  String get duplicatesPending => '똑같은 사진은 다 살펴본 뒤 알려 드려요 · 무료';

  @override
  String get nothingMarked => '정리할 사진이 없어요';

  @override
  String yearlyEnded(int count) {
    return '1년 이용권이 끝났어요 · 추천을 본 묶음은 그대로 열려 있고, 새 묶음은 이번 달 ◉ $count개로 열 수 있어요';
  }

  @override
  String get proUsing => 'Pro를 쓰고 있어요';

  @override
  String get privacyCortex =>
      'Cortex로 직접 보낸 사진·캡처는 Cortex에서 AI로 분석해요. 내가 고른 사진·캡처만, 보낼 때만 넘어가요.';

  @override
  String cortexNotSaved(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Cortex가 받았다는 신호가 없어서 휴지통으로 보내지 않았어요 · X는 그대로예요. Cortex에서 받은 걸 확인했다면 [$countString장 휴지통으로]를 누르면 돼요.';
  }

  @override
  String get tagOldShot => '오래됨';

  @override
  String get tagRepeatShot => '연달아 찍음';

  @override
  String get noteOldShot => '90일 넘은 캡처';

  @override
  String get noteRepeatShot => '바로 뒤에 같은 화면을 또 찍었어요';

  @override
  String accMuted(String names) {
    return '자주 되돌려서 당분간 추천하지 않는 이유(최근 30일): $names';
  }

  @override
  String get privacyPolicy => '개인정보처리방침';

  @override
  String cortexPartial(int count) {
    return 'Cortex가 $count장만 받았다고 알려 왔어요 · 휴지통으로 보내지 않았어요 · X는 그대로예요.';
  }

  @override
  String get accByKind => '종류별 (결제 기준은 그날의 묶음)';

  @override
  String get kindDay => '그날의 묶음';

  @override
  String get proFreeKinds => '캡처·낱장·똑같은 사진은 늘 무료';

  @override
  String freeRefilled(int count) {
    return '이번 달 ◉ $count개가 다시 생겼어요';
  }

  @override
  String freeTodoShots(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '지금 무료로: 캡처 추천 $countString장 보기 ›';
  }

  @override
  String freeTodoDuplicates(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '지금 무료로: 똑같은 사진 $countString장 보기 ›';
  }

  @override
  String get accRateDay => '그날의 묶음 추천을 받아들인 비율 (결제 기준)';

  @override
  String accRateAll(String rate) {
    return '모든 종류 합계 $rate (참고)';
  }

  @override
  String get mutedBurst => '비슷한 연속 컷은 자주 남기셔서 당분간 추천하지 않아요 · 30일 뒤에 다시 골라 볼게요';

  @override
  String get mutedBlurry => '흔들린 사진은 자주 남기셔서 당분간 추천하지 않아요 · 30일 뒤에 다시 골라 볼게요';

  @override
  String get mutedJunk => '실수로 찍힌 사진은 자주 남기셔서 당분간 추천하지 않아요 · 30일 뒤에 다시 골라 볼게요';

  @override
  String get useFreeSetTitle => '1개로 열까요?';

  @override
  String useFreeSetBody(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '추천 $countString장을 볼 수 있어요.\n한 번 열면 계속 열려 있어요.';
  }

  @override
  String get useFreeSetYes => '열기';

  @override
  String get toCortex => 'Cortex로';

  @override
  String cortexAskTitle(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString장을 Cortex로 보낼까요?';
  }

  @override
  String get cortexAskYes => '보내기';

  @override
  String noFreeLead(String date, int count) {
    return '이번 달 ◉ 0개 · $date에 $count개가 다시 생겨요';
  }

  @override
  String get cortexSentBadge => 'Cortex로 보냄';

  @override
  String cortexGotTitle(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '✓ Cortex가 $countString장 받았어요';
  }

  @override
  String get cortexGotBody =>
      '분석은 Cortex가 뒤에서 해요. 앱을 닫아도 돼요.\n이 사진을 휴지통으로 보낼까요?';

  @override
  String cortexGotKept(int kept) {
    final intl.NumberFormat keptNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String keptString = keptNumberFormat.format(kept);

    return 'Cortex가 받지 못한 $keptString장은 그대로 둬요.';
  }

  @override
  String get cortexGotBadge => 'Cortex에 있음';

  @override
  String get later => '나중에';

  @override
  String get focusFinishNone => '정리할 사진이 없어요. 끝낼까요?';

  @override
  String get focusKeepLooking => '계속 보기';

  @override
  String get focusFinishYes => '끝내기';

  @override
  String get focusHint => '길게 누르면 정리를 끝낼 수 있어요';

  @override
  String get focusFinishSemantics => '정리 끝내기';

  @override
  String barPhotos(Object size) {
    return '사진·동영상 $size';
  }

  @override
  String barSent(Object size) {
    return '휴지통 $size';
  }

  @override
  String get openGallery => '갤러리';

  @override
  String get noGallery => '갤러리 앱을 찾지 못했어요';

  @override
  String coinCount(int count) {
    return '코인 $count개';
  }

  @override
  String get picksDot => '추천 정리가 남았어요';

  @override
  String picksOn(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '추천 $countString장';
  }

  @override
  String get barRecommendedLabel => '추천 정리 ';

  @override
  String get tagEyesClosed => '눈 감음';

  @override
  String get noteEyesClosed => '눈 감은 컷 · 같은 순간 눈 뜬 컷이 있어요';

  @override
  String get mutedEyesClosed =>
      '눈 감은 컷은 자주 남기셔서 당분간 추천하지 않아요 · 30일 뒤에 다시 골라 볼게요';

  @override
  String get testFreeChip => '테스트 무료';

  @override
  String get renameTitle => '묶음 이름';

  @override
  String get renameReset => '원래 이름으로';

  @override
  String get save => '저장';

  @override
  String get privacyShortLocal => '사진과 정리 기록은 이 폰에만 저장돼요';

  @override
  String get privacyShortPlace => '장소 이름은 위치 좌표만 폰의 위치 서비스로 찾아요';

  @override
  String get privacyShortFaces => '눈 감은 컷은 폰 안에서만 확인해요';

  @override
  String get privacyShortTrash => '휴지통 사진은 30일 안에 되살릴 수 있어요';

  @override
  String get privacyShortCortex =>
      'Cortex에는 내가 고른 사진·캡처만, 보낼 때만 가요 (Cortex에서 AI로 분석해요)';

  @override
  String get helpTitle => '도움';

  @override
  String get clearAllSub => '분석 결과와 정리 기록을 지워요 · 사진은 그대로';

  @override
  String get coinWord => '코인';

  @override
  String get bigVideos => '큰 동영상';

  @override
  String videosMeta(int count, String size) {
    return '$count개 · $size';
  }

  @override
  String get cortexAskNote => 'Cortex에서 AI로 분석해요';

  @override
  String get cortexGetTitle => 'Cortex가 필요해요';

  @override
  String get cortexGetBody =>
      '사진·캡처를 메모로 정리해 주는 앱이에요. 받은 뒤 다시 [Cortex로]를 눌러 주세요.';

  @override
  String get cortexGetYes => '받으러 가기';

  @override
  String videosCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString개';
  }

  @override
  String trashCountVideos(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString개 휴지통으로';
  }

  @override
  String trashedVideos(int count, String size) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '✓ $countString개 · $size 휴지통으로 보냈어요 · 30일 안에 되살릴 수 있고, 휴지통을 비우면 그만큼 공간이 생겨요';
  }

  @override
  String get nothingMarkedVideos => '고른 동영상이 없어요';

  @override
  String get focusFinishNoneVideos => '고른 동영상이 없어요. 끝낼까요?';

  @override
  String get proTestFree => '비공개 테스트 동안은 모든 묶음 추천이 무료예요';

  @override
  String get proAtLaunch => 'Pro는 정식 출시 때 살 수 있어요';

  @override
  String cortexAskResend(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '이미 Cortex로 보낸 $countString장도 다시 보내요';
  }

  @override
  String proOnPhone(int groups, int count, String size) {
    final intl.NumberFormat groupsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String groupsString = groupsNumberFormat.format(groups);
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '이 폰에서: 잠긴 묶음 $groupsString개 · 추천 $countString장 · 약 $size';
  }

  @override
  String shotsReadyNow(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '캡처 $countString장은 지금 바로 정리할 수 있어요 ›';
  }

  @override
  String get playVideo => '재생';

  @override
  String get videoOpenFailed => '이 동영상을 열 앱을 찾지 못했어요';

  @override
  String testEnded(int count) {
    return '비공개 테스트가 끝났어요 · 이번 달 ◉ $count개';
  }
}
