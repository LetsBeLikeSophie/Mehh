import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L10n
/// returned by `L10n.of(context)`.
///
/// Applications need to include `L10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L10n.localizationsDelegates,
///   supportedLocales: L10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L10n.supportedLocales
/// property.
abstract class L10n {
  L10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L10n of(BuildContext context) {
    return Localizations.of<L10n>(context, L10n)!;
  }

  static const LocalizationsDelegate<L10n> delegate = _L10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ko, this message translates to:
  /// **'Mehh'**
  String get appTitle;

  /// 남기기로 결정 (용어, SPEC 5-0)
  ///
  /// In ko, this message translates to:
  /// **'킵'**
  String get keep;

  /// 지울 후보로 표시 (X). 아직 안 지움
  ///
  /// In ko, this message translates to:
  /// **'정리'**
  String get pile;

  /// 휴대폰 휴지통으로 실제로 보내는 버튼. OS 휴지통으로 가는 버튼은 항상 이 말
  ///
  /// In ko, this message translates to:
  /// **'휴지통으로'**
  String get toTrash;

  /// No description provided for @pileCancel.
  ///
  /// In ko, this message translates to:
  /// **'정리 취소'**
  String get pileCancel;

  /// No description provided for @back.
  ///
  /// In ko, this message translates to:
  /// **'돌아가기'**
  String get back;

  /// No description provided for @close.
  ///
  /// In ko, this message translates to:
  /// **'닫기'**
  String get close;

  /// No description provided for @home.
  ///
  /// In ko, this message translates to:
  /// **'홈으로'**
  String get home;

  /// No description provided for @settings.
  ///
  /// In ko, this message translates to:
  /// **'설정'**
  String get settings;

  /// No description provided for @cancel.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get cancel;

  /// No description provided for @retry.
  ///
  /// In ko, this message translates to:
  /// **'다시 시도'**
  String get retry;

  /// No description provided for @loadingGroups.
  ///
  /// In ko, this message translates to:
  /// **'사진을 묶는 중이에요'**
  String get loadingGroups;

  /// No description provided for @loadFailed.
  ///
  /// In ko, this message translates to:
  /// **'사진을 불러오지 못했어요'**
  String get loadFailed;

  /// No description provided for @noPhotos.
  ///
  /// In ko, this message translates to:
  /// **'정리할 사진이 없어요'**
  String get noPhotos;

  /// No description provided for @groupsLeft.
  ///
  /// In ko, this message translates to:
  /// **'정리할 묶음\n{count}개 남았어요'**
  String groupsLeft(int count);

  /// No description provided for @noGroupsLeft.
  ///
  /// In ko, this message translates to:
  /// **'지금은\n정리할 묶음이 없어요'**
  String get noGroupsLeft;

  /// No description provided for @sectionOthers.
  ///
  /// In ko, this message translates to:
  /// **'따로 보기'**
  String get sectionOthers;

  /// No description provided for @jumpToYear.
  ///
  /// In ko, this message translates to:
  /// **'연도 이동'**
  String get jumpToYear;

  /// No description provided for @freedThisMonth.
  ///
  /// In ko, this message translates to:
  /// **'이번 달 휴지통으로 {size} 보냈어요'**
  String freedThisMonth(String size);

  /// No description provided for @photoTotal.
  ///
  /// In ko, this message translates to:
  /// **'사진 {count}장'**
  String photoTotal(int count);

  /// No description provided for @analyzingPercent.
  ///
  /// In ko, this message translates to:
  /// **'사진 살펴보는 중 {percent}%'**
  String analyzingPercent(int percent);

  /// No description provided for @locatingPercent.
  ///
  /// In ko, this message translates to:
  /// **'장소 확인 중 {percent}%'**
  String locatingPercent(int percent);

  /// No description provided for @duplicatesFree.
  ///
  /// In ko, this message translates to:
  /// **'무료로 정리'**
  String get duplicatesFree;

  /// No description provided for @duplicatesFound.
  ///
  /// In ko, this message translates to:
  /// **'똑같은 사진 {count}장 찾았어요'**
  String duplicatesFound(int count);

  /// No description provided for @review.
  ///
  /// In ko, this message translates to:
  /// **'살펴보기'**
  String get review;

  /// No description provided for @photos.
  ///
  /// In ko, this message translates to:
  /// **'{count}장'**
  String photos(int count);

  /// No description provided for @suggestedCount.
  ///
  /// In ko, this message translates to:
  /// **'추천 정리 {count}장'**
  String suggestedCount(int count);

  /// No description provided for @analyzingShort.
  ///
  /// In ko, this message translates to:
  /// **'살펴보는 중'**
  String get analyzingShort;

  /// No description provided for @allSeen.
  ///
  /// In ko, this message translates to:
  /// **'다 봤어요'**
  String get allSeen;

  /// No description provided for @pickScreenshots.
  ///
  /// In ko, this message translates to:
  /// **'지울 캡처를 골라 보세요'**
  String get pickScreenshots;

  /// No description provided for @limitedAccess.
  ///
  /// In ko, this message translates to:
  /// **'일부 사진만 허용했어요.\n전체를 허용하면 더 많이 찾을 수 있어요.'**
  String get limitedAccess;

  /// No description provided for @choosePhotos.
  ///
  /// In ko, this message translates to:
  /// **'사진 고르기'**
  String get choosePhotos;

  /// No description provided for @screenshots.
  ///
  /// In ko, this message translates to:
  /// **'캡처'**
  String get screenshots;

  /// No description provided for @singles.
  ///
  /// In ko, this message translates to:
  /// **'낱장 사진'**
  String get singles;

  /// No description provided for @duplicatesTitle.
  ///
  /// In ko, this message translates to:
  /// **'똑같은 사진'**
  String get duplicatesTitle;

  /// No description provided for @reasonSharp.
  ///
  /// In ko, this message translates to:
  /// **'초점 선명'**
  String get reasonSharp;

  /// No description provided for @reasonExposure.
  ///
  /// In ko, this message translates to:
  /// **'밝기 적당'**
  String get reasonExposure;

  /// No description provided for @tagBest.
  ///
  /// In ko, this message translates to:
  /// **'베스트'**
  String get tagBest;

  /// No description provided for @tagBurst.
  ///
  /// In ko, this message translates to:
  /// **'비슷한 컷'**
  String get tagBurst;

  /// No description provided for @tagBlurry.
  ///
  /// In ko, this message translates to:
  /// **'흔들림'**
  String get tagBlurry;

  /// No description provided for @tagJunk.
  ///
  /// In ko, this message translates to:
  /// **'실수'**
  String get tagJunk;

  /// No description provided for @tagOriginal.
  ///
  /// In ko, this message translates to:
  /// **'남길 사진'**
  String get tagOriginal;

  /// No description provided for @tagDuplicate.
  ///
  /// In ko, this message translates to:
  /// **'똑같은 사진'**
  String get tagDuplicate;

  /// No description provided for @noteBestWith.
  ///
  /// In ko, this message translates to:
  /// **'베스트 · {reason}'**
  String noteBestWith(String reason);

  /// No description provided for @noteBurst.
  ///
  /// In ko, this message translates to:
  /// **'비슷한 연속 컷'**
  String get noteBurst;

  /// No description provided for @noteBlurry.
  ///
  /// In ko, this message translates to:
  /// **'더 선명한 컷이 있어요'**
  String get noteBlurry;

  /// No description provided for @noteJunk.
  ///
  /// In ko, this message translates to:
  /// **'실수로 찍힌 것 같아요'**
  String get noteJunk;

  /// No description provided for @noteKeeper.
  ///
  /// In ko, this message translates to:
  /// **'남길 사진'**
  String get noteKeeper;

  /// No description provided for @cortexFailed.
  ///
  /// In ko, this message translates to:
  /// **'Cortex로 보내지 못했어요'**
  String get cortexFailed;

  /// No description provided for @photoSemantics.
  ///
  /// In ko, this message translates to:
  /// **'사진. 위로 밀면 정리, 아래로 밀면 킵'**
  String get photoSemantics;

  /// No description provided for @nextPhoto.
  ///
  /// In ko, this message translates to:
  /// **'다음 사진'**
  String get nextPhoto;

  /// No description provided for @prevPhoto.
  ///
  /// In ko, this message translates to:
  /// **'이전 사진'**
  String get prevPhoto;

  /// No description provided for @trashBarSemantics.
  ///
  /// In ko, this message translates to:
  /// **'정리. 사진을 위로 올려도 돼요'**
  String get trashBarSemantics;

  /// No description provided for @markForRemoval.
  ///
  /// In ko, this message translates to:
  /// **'정리하기'**
  String get markForRemoval;

  /// No description provided for @sceneLossTitle.
  ///
  /// In ko, this message translates to:
  /// **'{count}개 장면은 사진이 하나도 안 남아요'**
  String sceneLossTitle(int count);

  /// No description provided for @sceneLossBody.
  ///
  /// In ko, this message translates to:
  /// **'비슷한 사진을 전부 선택했어요. 그래도 휴지통으로 보낼까요?'**
  String get sceneLossBody;

  /// No description provided for @lookAgain.
  ///
  /// In ko, this message translates to:
  /// **'다시 볼게요'**
  String get lookAgain;

  /// No description provided for @selectAll.
  ///
  /// In ko, this message translates to:
  /// **'전체 선택'**
  String get selectAll;

  /// No description provided for @deselectAll.
  ///
  /// In ko, this message translates to:
  /// **'선택 해제'**
  String get deselectAll;

  /// No description provided for @markedPhoto.
  ///
  /// In ko, this message translates to:
  /// **'정리할 사진'**
  String get markedPhoto;

  /// No description provided for @photo.
  ///
  /// In ko, this message translates to:
  /// **'사진'**
  String get photo;

  /// No description provided for @trashCount.
  ///
  /// In ko, this message translates to:
  /// **'{count}장 휴지통으로'**
  String trashCount(int count);

  /// No description provided for @countAndRange.
  ///
  /// In ko, this message translates to:
  /// **'{count} · {range}'**
  String countAndRange(String count, String range);

  /// No description provided for @trashFailed.
  ///
  /// In ko, this message translates to:
  /// **'휴지통으로 보내지 못했어요. 사진은 그대로예요.'**
  String get trashFailed;

  /// No description provided for @trashed.
  ///
  /// In ko, this message translates to:
  /// **'✓ {count}장 · {size} 휴지통으로 보냈어요 · 30일 안에 되살릴 수 있고, 휴지통을 비우면 그만큼 공간이 생겨요'**
  String trashed(int count, String size);

  /// No description provided for @clearTitle.
  ///
  /// In ko, this message translates to:
  /// **'모든 기록을 지울까요?'**
  String get clearTitle;

  /// No description provided for @clearBody.
  ///
  /// In ko, this message translates to:
  /// **'사진 분석 결과, 킵·정리 기록, 휴지통으로 보낸 용량 기록, 바꾼 묶음 이름, Cortex로 보낸 표시를 지워요.\n사진은 지워지지 않아요.'**
  String get clearBody;

  /// No description provided for @clearConfirm.
  ///
  /// In ko, this message translates to:
  /// **'지우기'**
  String get clearConfirm;

  /// No description provided for @cleared.
  ///
  /// In ko, this message translates to:
  /// **'기록을 모두 지웠어요'**
  String get cleared;

  /// No description provided for @privacyTitle.
  ///
  /// In ko, this message translates to:
  /// **'사진과 기록은 이 폰에만 있어요'**
  String get privacyTitle;

  /// No description provided for @privacyLocal.
  ///
  /// In ko, this message translates to:
  /// **'사진 분석과 정리·킵 기록은 이 폰 안에만 저장돼요. 서버로 보내지 않고, 클라우드 백업에도 넣지 않아요.'**
  String get privacyLocal;

  /// No description provided for @privacyGeocode.
  ///
  /// In ko, this message translates to:
  /// **'장소 이름을 찾을 때는 사진의 위치 좌표만 휴대폰의 위치 서비스로 보내요.'**
  String get privacyGeocode;

  /// No description provided for @privacyTrash.
  ///
  /// In ko, this message translates to:
  /// **'휴지통으로 보낸 사진은 30일 동안 갤러리 휴지통에서 되살릴 수 있어요.'**
  String get privacyTrash;

  /// No description provided for @clearAll.
  ///
  /// In ko, this message translates to:
  /// **'모든 기록 지우기'**
  String get clearAll;

  /// No description provided for @onboardingTitle.
  ///
  /// In ko, this message translates to:
  /// **'사진 정리,\n제가 먼저 해둘게요'**
  String get onboardingTitle;

  /// No description provided for @onboardingBody.
  ///
  /// In ko, this message translates to:
  /// **'찍은 날짜와 장소로 사진을 묶고, 똑같은 사진과 큰 동영상을 찾으려면 사진·동영상 전체에 접근해야 해요.'**
  String get onboardingBody;

  /// No description provided for @promiseLocal.
  ///
  /// In ko, this message translates to:
  /// **'사진과 기록은 폰 밖으로 나가지 않아요.'**
  String get promiseLocal;

  /// No description provided for @promiseLearn.
  ///
  /// In ko, this message translates to:
  /// **'추천은 앱이 먼저 골라 둔 것일 뿐이에요. 언제든 바꿀 수 있어요.'**
  String get promiseLearn;

  /// No description provided for @promiseRestore.
  ///
  /// In ko, this message translates to:
  /// **'휴지통으로 보낸 사진은 30일 동안 갤러리 휴지통에서 되살릴 수 있어요.'**
  String get promiseRestore;

  /// No description provided for @allowAccess.
  ///
  /// In ko, this message translates to:
  /// **'사진·동영상 접근 허용'**
  String get allowAccess;

  /// No description provided for @allowInSettings.
  ///
  /// In ko, this message translates to:
  /// **'설정에서 허용하기'**
  String get allowInSettings;

  /// No description provided for @billingPending.
  ///
  /// In ko, this message translates to:
  /// **'결제를 확인하는 중이에요'**
  String get billingPending;

  /// No description provided for @billingFailed.
  ///
  /// In ko, this message translates to:
  /// **'결제를 마치지 못했어요'**
  String get billingFailed;

  /// No description provided for @billingUnavailable.
  ///
  /// In ko, this message translates to:
  /// **'지금은 스토어에 연결할 수 없어요'**
  String get billingUnavailable;

  /// No description provided for @billingDemo.
  ///
  /// In ko, this message translates to:
  /// **'미리보기라 실제로 결제되지 않아요'**
  String get billingDemo;

  /// No description provided for @proChip.
  ///
  /// In ko, this message translates to:
  /// **'Pro'**
  String get proChip;

  /// No description provided for @proTitle.
  ///
  /// In ko, this message translates to:
  /// **'Mehh Pro'**
  String get proTitle;

  /// No description provided for @proBody.
  ///
  /// In ko, this message translates to:
  /// **'모든 묶음의 추천 정리를 바로 봐요'**
  String get proBody;

  /// No description provided for @proFree.
  ///
  /// In ko, this message translates to:
  /// **'Pro 없이: 묶음 하나에 ◉ 1개 · 매달 {limit}개 · {count}개 남음 · {date} 다시 채움'**
  String proFree(int limit, int count, String date);

  /// No description provided for @proActive.
  ///
  /// In ko, this message translates to:
  /// **'Pro를 쓰고 있어요. 모든 묶음의 추천이 열려 있어요.'**
  String get proActive;

  /// No description provided for @planLifetime.
  ///
  /// In ko, this message translates to:
  /// **'평생 이용권'**
  String get planLifetime;

  /// No description provided for @planLifetimeNote.
  ///
  /// In ko, this message translates to:
  /// **'한 번 사면 계속 써요'**
  String get planLifetimeNote;

  /// No description provided for @planYearly.
  ///
  /// In ko, this message translates to:
  /// **'1년 이용권'**
  String get planYearly;

  /// No description provided for @planYearlyNote.
  ///
  /// In ko, this message translates to:
  /// **'매년 자동 갱신 · 언제든 해지'**
  String get planYearlyNote;

  /// No description provided for @planBest.
  ///
  /// In ko, this message translates to:
  /// **'추천'**
  String get planBest;

  /// No description provided for @proNotes.
  ///
  /// In ko, this message translates to:
  /// **'회원 가입 없음 · 폰을 바꾸면 [구매 복원]'**
  String get proNotes;

  /// No description provided for @restorePurchases.
  ///
  /// In ko, this message translates to:
  /// **'구매 복원'**
  String get restorePurchases;

  /// No description provided for @restored.
  ///
  /// In ko, this message translates to:
  /// **'구매를 복원했어요'**
  String get restored;

  /// No description provided for @nothingToRestore.
  ///
  /// In ko, this message translates to:
  /// **'복원할 구매가 없어요'**
  String get nothingToRestore;

  /// No description provided for @proThanks.
  ///
  /// In ko, this message translates to:
  /// **'Pro가 열렸어요'**
  String get proThanks;

  /// No description provided for @proNudge.
  ///
  /// In ko, this message translates to:
  /// **'{count}장을 휴지통으로 보냈어요 · 30일 안에 되살릴 수 있고, 휴지통을 비우면 공간이 생겨요. 남은 묶음도 추천을 바로 볼까요?'**
  String proNudge(int count);

  /// No description provided for @contact.
  ///
  /// In ko, this message translates to:
  /// **'문의하기'**
  String get contact;

  /// No description provided for @contactSubject.
  ///
  /// In ko, this message translates to:
  /// **'Mehh 문의 ({version})'**
  String contactSubject(String version);

  /// No description provided for @contactNote.
  ///
  /// In ko, this message translates to:
  /// **'{email} · 사진이나 기록은 저절로 보내지 않아요. 메일에 적은 것만 받아요.'**
  String contactNote(String email);

  /// No description provided for @contactCopied.
  ///
  /// In ko, this message translates to:
  /// **'메일 주소를 복사했어요'**
  String get contactCopied;

  /// No description provided for @accTitle.
  ///
  /// In ko, this message translates to:
  /// **'추천 정확도'**
  String get accTitle;

  /// No description provided for @accEmpty.
  ///
  /// In ko, this message translates to:
  /// **'아직 기록이 없어요. 묶음을 정리하고 [휴지통으로]를 누르면 쌓여요.'**
  String get accEmpty;

  /// No description provided for @accRate.
  ///
  /// In ko, this message translates to:
  /// **'추천을 받아들인 비율'**
  String get accRate;

  /// No description provided for @accSends.
  ///
  /// In ko, this message translates to:
  /// **'{count}번 휴지통으로 보냈어요'**
  String accSends(int count);

  /// No description provided for @accAccepted.
  ///
  /// In ko, this message translates to:
  /// **'앱이 추천한 {total}장 중 {count}장을 보냈어요'**
  String accAccepted(int count, int total);

  /// No description provided for @accAdded.
  ///
  /// In ko, this message translates to:
  /// **'앱이 놓쳐서 직접 고른 사진 {count}장'**
  String accAdded(int count);

  /// No description provided for @accBest.
  ///
  /// In ko, this message translates to:
  /// **'베스트로 고른 사진을 남긴 비율'**
  String get accBest;

  /// No description provided for @accByTag.
  ///
  /// In ko, this message translates to:
  /// **'이유별'**
  String get accByTag;

  /// No description provided for @accTagLine.
  ///
  /// In ko, this message translates to:
  /// **'{count}/{total}장'**
  String accTagLine(int count, int total);

  /// No description provided for @accNote.
  ///
  /// In ko, this message translates to:
  /// **'이 기록은 이 폰에만 있어요. 그날의 묶음 비율이 80%를 넘으면 결제를 켤 만해요.'**
  String get accNote;

  /// No description provided for @cortexMultiUnsupported.
  ///
  /// In ko, this message translates to:
  /// **'Cortex가 아직 여러 장 받기를 못 해요. Cortex를 업데이트해 주세요.'**
  String get cortexMultiUnsupported;

  /// No description provided for @showPicks.
  ///
  /// In ko, this message translates to:
  /// **'추천 보기 · {count}장'**
  String showPicks(int count);

  /// No description provided for @keepBarSemantics.
  ///
  /// In ko, this message translates to:
  /// **'킵. 사진을 아래로 내려도 돼요'**
  String get keepBarSemantics;

  /// No description provided for @lookingAtPhotos.
  ///
  /// In ko, this message translates to:
  /// **'사진을\n살펴보고 있어요'**
  String get lookingAtPhotos;

  /// No description provided for @duplicatesPending.
  ///
  /// In ko, this message translates to:
  /// **'똑같은 사진은 다 살펴본 뒤 알려 드려요 · 무료'**
  String get duplicatesPending;

  /// No description provided for @nothingMarked.
  ///
  /// In ko, this message translates to:
  /// **'정리할 사진이 없어요'**
  String get nothingMarked;

  /// No description provided for @yearlyEnded.
  ///
  /// In ko, this message translates to:
  /// **'1년 이용권이 끝났어요 · 추천을 본 묶음은 그대로 열려 있고, 새 묶음은 이번 달 ◉ {count}개로 열 수 있어요'**
  String yearlyEnded(int count);

  /// No description provided for @proUsing.
  ///
  /// In ko, this message translates to:
  /// **'Pro를 쓰고 있어요'**
  String get proUsing;

  /// No description provided for @privacyCortex.
  ///
  /// In ko, this message translates to:
  /// **'Cortex로 직접 보낸 사진·캡처는 Cortex에서 AI로 분석해요. 내가 고른 사진·캡처만, 보낼 때만 넘어가요.'**
  String get privacyCortex;

  /// No description provided for @cortexNotSaved.
  ///
  /// In ko, this message translates to:
  /// **'Cortex가 받았다는 신호가 없어서 휴지통으로 보내지 않았어요 · X는 그대로예요. Cortex에서 받은 걸 확인했다면 [{count}장 휴지통으로]를 누르면 돼요.'**
  String cortexNotSaved(int count);

  /// No description provided for @tagOldShot.
  ///
  /// In ko, this message translates to:
  /// **'오래됨'**
  String get tagOldShot;

  /// No description provided for @tagRepeatShot.
  ///
  /// In ko, this message translates to:
  /// **'연달아 찍음'**
  String get tagRepeatShot;

  /// No description provided for @noteOldShot.
  ///
  /// In ko, this message translates to:
  /// **'90일 넘은 캡처'**
  String get noteOldShot;

  /// No description provided for @noteRepeatShot.
  ///
  /// In ko, this message translates to:
  /// **'바로 뒤에 같은 화면을 또 찍었어요'**
  String get noteRepeatShot;

  /// No description provided for @accMuted.
  ///
  /// In ko, this message translates to:
  /// **'자주 되돌려서 당분간 추천하지 않는 이유(최근 30일): {names}'**
  String accMuted(String names);

  /// No description provided for @privacyPolicy.
  ///
  /// In ko, this message translates to:
  /// **'개인정보처리방침'**
  String get privacyPolicy;

  /// No description provided for @termsRefunds.
  ///
  /// In ko, this message translates to:
  /// **'이용약관·환불'**
  String get termsRefunds;

  /// No description provided for @cortexPartial.
  ///
  /// In ko, this message translates to:
  /// **'Cortex가 {count}장만 받았다고 알려 왔어요 · 휴지통으로 보내지 않았어요 · X는 그대로예요.'**
  String cortexPartial(int count);

  /// No description provided for @accByKind.
  ///
  /// In ko, this message translates to:
  /// **'종류별 (결제 기준은 그날의 묶음)'**
  String get accByKind;

  /// No description provided for @kindDay.
  ///
  /// In ko, this message translates to:
  /// **'그날의 묶음'**
  String get kindDay;

  /// No description provided for @proFreeKinds.
  ///
  /// In ko, this message translates to:
  /// **'캡처·낱장·똑같은 사진은 늘 무료'**
  String get proFreeKinds;

  /// No description provided for @freeRefilled.
  ///
  /// In ko, this message translates to:
  /// **'이번 달 ◉ {count}개가 다시 생겼어요'**
  String freeRefilled(int count);

  /// No description provided for @freeTodoShots.
  ///
  /// In ko, this message translates to:
  /// **'지금 무료로: 캡처 추천 {count}장 보기 ›'**
  String freeTodoShots(int count);

  /// No description provided for @freeTodoDuplicates.
  ///
  /// In ko, this message translates to:
  /// **'지금 무료로: 똑같은 사진 {count}장 보기 ›'**
  String freeTodoDuplicates(int count);

  /// No description provided for @accRateDay.
  ///
  /// In ko, this message translates to:
  /// **'그날의 묶음 추천을 받아들인 비율 (결제 기준)'**
  String get accRateDay;

  /// No description provided for @accRateAll.
  ///
  /// In ko, this message translates to:
  /// **'모든 종류 합계 {rate} (참고)'**
  String accRateAll(String rate);

  /// No description provided for @mutedBurst.
  ///
  /// In ko, this message translates to:
  /// **'비슷한 연속 컷은 자주 남기셔서 당분간 추천하지 않아요 · 30일 뒤에 다시 골라 볼게요'**
  String get mutedBurst;

  /// No description provided for @mutedBlurry.
  ///
  /// In ko, this message translates to:
  /// **'흔들린 사진은 자주 남기셔서 당분간 추천하지 않아요 · 30일 뒤에 다시 골라 볼게요'**
  String get mutedBlurry;

  /// No description provided for @mutedJunk.
  ///
  /// In ko, this message translates to:
  /// **'실수로 찍힌 사진은 자주 남기셔서 당분간 추천하지 않아요 · 30일 뒤에 다시 골라 볼게요'**
  String get mutedJunk;

  /// No description provided for @useFreeSetTitle.
  ///
  /// In ko, this message translates to:
  /// **'1개로 열까요?'**
  String get useFreeSetTitle;

  /// No description provided for @useFreeSetBody.
  ///
  /// In ko, this message translates to:
  /// **'추천 {count}장을 볼 수 있어요.\n한 번 열면 계속 열려 있어요.'**
  String useFreeSetBody(int count);

  /// No description provided for @useFreeSetYes.
  ///
  /// In ko, this message translates to:
  /// **'열기'**
  String get useFreeSetYes;

  /// No description provided for @toCortex.
  ///
  /// In ko, this message translates to:
  /// **'Cortex로'**
  String get toCortex;

  /// No description provided for @cortexAskTitle.
  ///
  /// In ko, this message translates to:
  /// **'{count}장을 Cortex로 보낼까요?'**
  String cortexAskTitle(int count);

  /// No description provided for @cortexAskYes.
  ///
  /// In ko, this message translates to:
  /// **'보내기'**
  String get cortexAskYes;

  /// No description provided for @noFreeLead.
  ///
  /// In ko, this message translates to:
  /// **'이번 달 ◉ 0개 · {date}에 {count}개가 다시 생겨요'**
  String noFreeLead(String date, int count);

  /// No description provided for @cortexSentBadge.
  ///
  /// In ko, this message translates to:
  /// **'Cortex로 보냄'**
  String get cortexSentBadge;

  /// No description provided for @cortexGotTitle.
  ///
  /// In ko, this message translates to:
  /// **'✓ Cortex가 {count}장 받았어요'**
  String cortexGotTitle(int count);

  /// No description provided for @cortexGotBody.
  ///
  /// In ko, this message translates to:
  /// **'분석은 Cortex가 뒤에서 해요. 앱을 닫아도 돼요.\n이 사진을 휴지통으로 보낼까요?'**
  String get cortexGotBody;

  /// No description provided for @cortexGotKept.
  ///
  /// In ko, this message translates to:
  /// **'Cortex가 받지 못한 {kept}장은 그대로 둬요.'**
  String cortexGotKept(int kept);

  /// No description provided for @cortexGotBadge.
  ///
  /// In ko, this message translates to:
  /// **'Cortex에 있음'**
  String get cortexGotBadge;

  /// No description provided for @later.
  ///
  /// In ko, this message translates to:
  /// **'나중에'**
  String get later;

  /// No description provided for @focusFinishNone.
  ///
  /// In ko, this message translates to:
  /// **'정리할 사진이 없어요. 끝낼까요?'**
  String get focusFinishNone;

  /// No description provided for @focusKeepLooking.
  ///
  /// In ko, this message translates to:
  /// **'계속 보기'**
  String get focusKeepLooking;

  /// No description provided for @focusFinishYes.
  ///
  /// In ko, this message translates to:
  /// **'끝내기'**
  String get focusFinishYes;

  /// No description provided for @focusHint.
  ///
  /// In ko, this message translates to:
  /// **'길게 누르면 정리를 끝낼 수 있어요'**
  String get focusHint;

  /// No description provided for @focusFinishSemantics.
  ///
  /// In ko, this message translates to:
  /// **'정리 끝내기'**
  String get focusFinishSemantics;

  /// No description provided for @barPhotos.
  ///
  /// In ko, this message translates to:
  /// **'사진·동영상 {size}'**
  String barPhotos(Object size);

  /// No description provided for @barSent.
  ///
  /// In ko, this message translates to:
  /// **'휴지통 {size}'**
  String barSent(Object size);

  /// No description provided for @openGallery.
  ///
  /// In ko, this message translates to:
  /// **'갤러리'**
  String get openGallery;

  /// No description provided for @noGallery.
  ///
  /// In ko, this message translates to:
  /// **'갤러리 앱을 찾지 못했어요'**
  String get noGallery;

  /// No description provided for @coinCount.
  ///
  /// In ko, this message translates to:
  /// **'코인 {count}개'**
  String coinCount(int count);

  /// No description provided for @picksDot.
  ///
  /// In ko, this message translates to:
  /// **'추천 정리가 남았어요'**
  String get picksDot;

  /// No description provided for @picksOn.
  ///
  /// In ko, this message translates to:
  /// **'추천 {count}장'**
  String picksOn(int count);

  /// No description provided for @barRecommendedLabel.
  ///
  /// In ko, this message translates to:
  /// **'추천 정리 '**
  String get barRecommendedLabel;

  /// No description provided for @tagEyesClosed.
  ///
  /// In ko, this message translates to:
  /// **'눈 감음'**
  String get tagEyesClosed;

  /// No description provided for @noteEyesClosed.
  ///
  /// In ko, this message translates to:
  /// **'눈 감은 컷 · 같은 순간 눈 뜬 컷이 있어요'**
  String get noteEyesClosed;

  /// No description provided for @mutedEyesClosed.
  ///
  /// In ko, this message translates to:
  /// **'눈 감은 컷은 자주 남기셔서 당분간 추천하지 않아요 · 30일 뒤에 다시 골라 볼게요'**
  String get mutedEyesClosed;

  /// No description provided for @testFreeChip.
  ///
  /// In ko, this message translates to:
  /// **'테스트 무료'**
  String get testFreeChip;

  /// No description provided for @renameTitle.
  ///
  /// In ko, this message translates to:
  /// **'묶음 이름'**
  String get renameTitle;

  /// No description provided for @renameReset.
  ///
  /// In ko, this message translates to:
  /// **'원래 이름으로'**
  String get renameReset;

  /// No description provided for @save.
  ///
  /// In ko, this message translates to:
  /// **'저장'**
  String get save;

  /// No description provided for @privacyShortLocal.
  ///
  /// In ko, this message translates to:
  /// **'사진과 정리 기록은 이 폰에만 저장돼요'**
  String get privacyShortLocal;

  /// No description provided for @privacyShortPlace.
  ///
  /// In ko, this message translates to:
  /// **'장소 이름은 위치 좌표만 폰의 위치 서비스로 찾아요'**
  String get privacyShortPlace;

  /// No description provided for @privacyShortFaces.
  ///
  /// In ko, this message translates to:
  /// **'눈 감은 컷은 폰 안에서만 확인해요'**
  String get privacyShortFaces;

  /// No description provided for @privacyShortTrash.
  ///
  /// In ko, this message translates to:
  /// **'휴지통 사진은 30일 안에 되살릴 수 있어요'**
  String get privacyShortTrash;

  /// No description provided for @privacyShortCortex.
  ///
  /// In ko, this message translates to:
  /// **'Cortex에는 내가 고른 사진·캡처만, 보낼 때만 가요 (Cortex에서 AI로 분석해요)'**
  String get privacyShortCortex;

  /// No description provided for @helpTitle.
  ///
  /// In ko, this message translates to:
  /// **'도움'**
  String get helpTitle;

  /// No description provided for @clearAllSub.
  ///
  /// In ko, this message translates to:
  /// **'분석 결과와 정리 기록을 지워요 · 사진은 그대로'**
  String get clearAllSub;

  /// No description provided for @coinWord.
  ///
  /// In ko, this message translates to:
  /// **'코인'**
  String get coinWord;

  /// No description provided for @bigVideos.
  ///
  /// In ko, this message translates to:
  /// **'큰 동영상'**
  String get bigVideos;

  /// No description provided for @videosMeta.
  ///
  /// In ko, this message translates to:
  /// **'{count}개 · {size}'**
  String videosMeta(int count, String size);

  /// No description provided for @cortexAskNote.
  ///
  /// In ko, this message translates to:
  /// **'Cortex에서 AI로 분석해요'**
  String get cortexAskNote;

  /// No description provided for @cortexGetTitle.
  ///
  /// In ko, this message translates to:
  /// **'Cortex가 필요해요'**
  String get cortexGetTitle;

  /// No description provided for @cortexGetBody.
  ///
  /// In ko, this message translates to:
  /// **'사진·캡처를 메모로 정리해 주는 앱이에요. 받은 뒤 다시 [Cortex로]를 눌러 주세요.'**
  String get cortexGetBody;

  /// No description provided for @cortexGetYes.
  ///
  /// In ko, this message translates to:
  /// **'받으러 가기'**
  String get cortexGetYes;

  /// 큰 동영상 개수 (정리 화면 제목 뒤)
  ///
  /// In ko, this message translates to:
  /// **'{count}개'**
  String videosCount(int count);

  /// 큰 동영상 화면의 [휴지통으로] 버튼·확인 창 제목
  ///
  /// In ko, this message translates to:
  /// **'{count}개 휴지통으로'**
  String trashCountVideos(int count);

  /// 큰 동영상을 휴지통으로 보낸 뒤 알림
  ///
  /// In ko, this message translates to:
  /// **'✓ {count}개 · {size} 휴지통으로 보냈어요 · 30일 안에 되살릴 수 있고, 휴지통을 비우면 그만큼 공간이 생겨요'**
  String trashedVideos(int count, String size);

  /// 큰 동영상 화면에서 아무것도 안 골랐을 때 흐린 버튼
  ///
  /// In ko, this message translates to:
  /// **'고른 동영상이 없어요'**
  String get nothingMarkedVideos;

  /// 큰 동영상에서 고른 것 없이 길게 눌러 끝낼 때 확인 창
  ///
  /// In ko, this message translates to:
  /// **'고른 동영상이 없어요. 끝낼까요?'**
  String get focusFinishNoneVideos;

  /// 비공개 테스트 동안 Pro 시트의 코인 줄 대신
  ///
  /// In ko, this message translates to:
  /// **'비공개 테스트 동안은 모든 묶음 추천이 무료예요'**
  String get proTestFree;

  /// 비공개 테스트 동안 Pro 시트의 상품 목록 자리
  ///
  /// In ko, this message translates to:
  /// **'Pro는 정식 출시 때 살 수 있어요'**
  String get proAtLaunch;

  /// Cortex로 보낼까요? 창: 고른 사진 중 이미 보낸 장수
  ///
  /// In ko, this message translates to:
  /// **'이미 Cortex로 보낸 {count}장도 다시 보내요'**
  String cortexAskResend(int count);

  /// Pro 안내 상품 위: 이 폰의 잠긴 묶음·추천 장수·용량
  ///
  /// In ko, this message translates to:
  /// **'이 폰에서: 잠긴 묶음 {groups}개 · 추천 {count}장 · 약 {size}'**
  String proOnPhone(int groups, int count, String size);

  /// 처음 사진을 살펴보는 동안 홈 큰 글씨 아래: 캡처 추천은 이미 준비됨
  ///
  /// In ko, this message translates to:
  /// **'캡처 {count}장은 지금 바로 정리할 수 있어요 ›'**
  String shotsReadyNow(int count);

  /// 큰 동영상 크게 보기의 ▶ 버튼 (읽어 주기용 이름)
  ///
  /// In ko, this message translates to:
  /// **'재생'**
  String get playVideo;

  /// ▶를 눌렀는데 동영상을 열 앱이 없을 때
  ///
  /// In ko, this message translates to:
  /// **'이 동영상을 열 앱을 찾지 못했어요'**
  String get videoOpenFailed;

  /// 비공개 테스트가 끝나고 처음 켤 때 한 번
  ///
  /// In ko, this message translates to:
  /// **'비공개 테스트가 끝났어요 · 이번 달 ◉ {count}개'**
  String testEnded(int count);

  /// 일부만 허용했는데 허용한 사진이 0장일 때 홈
  ///
  /// In ko, this message translates to:
  /// **'허용한 사진이 없어요'**
  String get noAllowedPhotos;

  /// Cortex로 보낼까요? 창: 고른 사진 중 Cortex가 이미 받아 빼는 장수
  ///
  /// In ko, this message translates to:
  /// **'이미 Cortex에 있는 {count}장은 빼요'**
  String cortexAskSkip(int count);
}

class _L10nDelegate extends LocalizationsDelegate<L10n> {
  const _L10nDelegate();

  @override
  Future<L10n> load(Locale locale) {
    return SynchronousFuture<L10n>(lookupL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_L10nDelegate old) => false;
}

L10n lookupL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return L10nEn();
    case 'ko':
      return L10nKo();
  }

  throw FlutterError(
    'L10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
