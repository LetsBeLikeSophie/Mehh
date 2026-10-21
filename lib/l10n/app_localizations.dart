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

  /// No description provided for @keepCancel.
  ///
  /// In ko, this message translates to:
  /// **'킵 취소'**
  String get keepCancel;

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

  /// No description provided for @undo.
  ///
  /// In ko, this message translates to:
  /// **'되돌리기'**
  String get undo;

  /// No description provided for @reset.
  ///
  /// In ko, this message translates to:
  /// **'되돌리기'**
  String get reset;

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
  /// **'이번 달 {size} 비웠어요'**
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
  /// **'정리 추천 {count}장'**
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
  /// **'한 장 사진'**
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

  /// No description provided for @summaryJunk.
  ///
  /// In ko, this message translates to:
  /// **'실수로 찍힌 사진 {count}장'**
  String summaryJunk(int count);

  /// No description provided for @summaryBlurry.
  ///
  /// In ko, this message translates to:
  /// **'더 선명한 컷이 있는 흔들린 사진 {count}장'**
  String summaryBlurry(int count);

  /// No description provided for @summaryBurst.
  ///
  /// In ko, this message translates to:
  /// **'비슷한 연속 컷 {count}장'**
  String summaryBurst(int count);

  /// No description provided for @summaryDuplicates.
  ///
  /// In ko, this message translates to:
  /// **'묶음마다 하나만 남기고 똑같은 사진에 X를 쳐 뒀어요'**
  String get summaryDuplicates;

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

  /// No description provided for @sendToCortex.
  ///
  /// In ko, this message translates to:
  /// **'Cortex로 보내기'**
  String get sendToCortex;

  /// No description provided for @cortexSent.
  ///
  /// In ko, this message translates to:
  /// **'Cortex로 보냈어요 · 정리에 넣어 뒀어요'**
  String get cortexSent;

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

  /// No description provided for @resetTitle.
  ///
  /// In ko, this message translates to:
  /// **'처음 상태로 되돌릴까요?'**
  String get resetTitle;

  /// No description provided for @sceneLossTitle.
  ///
  /// In ko, this message translates to:
  /// **'{count}개 장면은 사진이 하나도 안 남아요'**
  String sceneLossTitle(int count);

  /// No description provided for @sceneLossBody.
  ///
  /// In ko, this message translates to:
  /// **'비슷한 사진에 전부 X를 쳤어요. 그래도 휴지통으로 보낼까요?'**
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

  /// No description provided for @analyzingTitle.
  ///
  /// In ko, this message translates to:
  /// **'사진을 살펴보는 중이에요'**
  String get analyzingTitle;

  /// No description provided for @analyzingDetail.
  ///
  /// In ko, this message translates to:
  /// **'추천이 조금씩 채워져요.'**
  String get analyzingDetail;

  /// No description provided for @noneFound.
  ///
  /// In ko, this message translates to:
  /// **'정리할 사진을 못 찾았어요'**
  String get noneFound;

  /// No description provided for @willRemoveSuffix.
  ///
  /// In ko, this message translates to:
  /// **' 정리할게요'**
  String get willRemoveSuffix;

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
  /// **'{count}장을 휴지통으로 보냈어요 · 갤러리 휴지통에서 30일 동안 되살릴 수 있어요'**
  String trashed(int count);

  /// No description provided for @clearTitle.
  ///
  /// In ko, this message translates to:
  /// **'모든 기록을 지울까요?'**
  String get clearTitle;

  /// No description provided for @clearBody.
  ///
  /// In ko, this message translates to:
  /// **'사진 분석 결과, 킵·정리 기록, 비운 용량 기록을 지워요.\n사진은 지워지지 않아요.'**
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
  /// **'찍은 날짜와 장소로 사진을 묶고, 똑같은 사진을 찾으려면 사진 전체에 접근해야 해요.'**
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
  /// **'사진 접근 허용'**
  String get allowAccess;

  /// No description provided for @allowInSettings.
  ///
  /// In ko, this message translates to:
  /// **'설정에서 허용하기'**
  String get allowInSettings;
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
