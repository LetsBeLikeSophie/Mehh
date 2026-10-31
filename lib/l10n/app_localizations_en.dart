// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class L10nEn extends L10n {
  L10nEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Mehh';

  @override
  String get keep => 'Keep';

  @override
  String get pile => 'Remove';

  @override
  String get toTrash => 'Move to trash';

  @override
  String get pileCancel => 'Undo remove';

  @override
  String get back => 'Back';

  @override
  String get close => 'Close';

  @override
  String get home => 'Home';

  @override
  String get settings => 'Settings';

  @override
  String get cancel => 'Cancel';

  @override
  String get retry => 'Try again';

  @override
  String get loadingGroups => 'Grouping your photos…';

  @override
  String get loadFailed => 'Couldn\'t load your photos';

  @override
  String get noPhotos => 'No photos to clean up';

  @override
  String groupsLeft(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString sets left\nto clean up',
      one: '1 set left\nto clean up',
    );
    return '$_temp0';
  }

  @override
  String get noGroupsLeft => 'Nothing left\nto clean up';

  @override
  String get sectionOthers => 'More';

  @override
  String get jumpToYear => 'Jump to year';

  @override
  String freedThisMonth(String size) {
    return 'Sent $size to trash this month';
  }

  @override
  String photoTotal(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString photos',
      one: '1 photo',
    );
    return '$_temp0';
  }

  @override
  String analyzingPercent(int percent) {
    return 'Analyzing photos $percent%';
  }

  @override
  String locatingPercent(int percent) {
    return 'Finding places $percent%';
  }

  @override
  String get duplicatesFree => 'Free cleanup';

  @override
  String duplicatesFound(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Found $countString duplicates',
      one: 'Found 1 duplicate',
    );
    return '$_temp0';
  }

  @override
  String get review => 'Review';

  @override
  String photos(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString photos',
      one: '1 photo',
    );
    return '$_temp0';
  }

  @override
  String suggestedCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString suggested';
  }

  @override
  String get analyzingShort => 'Analyzing';

  @override
  String get allSeen => 'All done';

  @override
  String get pickScreenshots => 'Pick screenshots to remove';

  @override
  String get limitedAccess =>
      'You\'ve allowed only some photos.\nAllow all to find more.';

  @override
  String get choosePhotos => 'Choose photos';

  @override
  String get screenshots => 'Screenshots';

  @override
  String get singles => 'Single shots';

  @override
  String get duplicatesTitle => 'Exact duplicates';

  @override
  String get reasonSharp => 'Sharp focus';

  @override
  String get reasonExposure => 'Good exposure';

  @override
  String get tagBest => 'Best';

  @override
  String get tagBurst => 'Similar';

  @override
  String get tagBlurry => 'Blurry';

  @override
  String get tagJunk => 'Accidental';

  @override
  String get tagOriginal => 'Keeping';

  @override
  String get tagDuplicate => 'Duplicate';

  @override
  String noteBestWith(String reason) {
    return 'Best · $reason';
  }

  @override
  String get noteBurst => 'Similar to nearby shots';

  @override
  String get noteBlurry => 'A sharper shot exists';

  @override
  String get noteJunk => 'Looks accidental';

  @override
  String get noteKeeper => 'Keeping this one';

  @override
  String get cortexFailed => 'Couldn\'t send to Cortex';

  @override
  String get photoSemantics => 'Photo. Swipe up to remove, down to keep';

  @override
  String get nextPhoto => 'Next photo';

  @override
  String get prevPhoto => 'Previous photo';

  @override
  String get trashBarSemantics => 'Remove. You can also swipe the photo up';

  @override
  String get markForRemoval => 'Mark for removal';

  @override
  String sceneLossTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count moments will have no photos left',
      one: '1 moment will have no photos left',
    );
    return '$_temp0';
  }

  @override
  String get sceneLossBody =>
      'You selected every similar photo. Move them to trash anyway?';

  @override
  String get lookAgain => 'Look again';

  @override
  String get selectAll => 'Select all';

  @override
  String get deselectAll => 'Deselect all';

  @override
  String get markedPhoto => 'Marked for removal';

  @override
  String get photo => 'Photo';

  @override
  String trashCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Move $countString to trash';
  }

  @override
  String countAndRange(String count, String range) {
    return '$count · $range';
  }

  @override
  String get trashFailed =>
      'Couldn\'t move to trash. Your photos are unchanged.';

  @override
  String trashed(int count, String size) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '✓ $countString photos · $size moved to trash · restore them within 30 days, or empty the trash to free up that space',
      one:
          '✓ 1 photo · $size moved to trash · restore it within 30 days, or empty the trash to free up that space',
    );
    return '$_temp0';
  }

  @override
  String get clearTitle => 'Clear all records?';

  @override
  String get clearBody =>
      'This clears photo analysis, keep/remove records, trashed-size history, renamed sets and Sent to Cortex marks.\nYour photos aren\'t deleted.';

  @override
  String get clearConfirm => 'Clear';

  @override
  String get cleared => 'All records cleared';

  @override
  String get privacyTitle => 'Your photos and records stay on this phone';

  @override
  String get privacyLocal =>
      'Photo analysis and keep/remove records are stored only on this phone. Nothing is sent to a server or included in cloud backups.';

  @override
  String get privacyGeocode =>
      'To show place names, only a photo\'s location coordinates are sent to your phone\'s location service.';

  @override
  String get privacyTrash =>
      'Photos moved to trash can be restored from your gallery\'s trash for 30 days.';

  @override
  String get clearAll => 'Clear all records';

  @override
  String get onboardingTitle => 'Photo cleanup,\nI\'ll do the first pass';

  @override
  String get onboardingBody =>
      'To group photos by date and place and find duplicates and big videos, Mehh needs access to all your photos and videos.';

  @override
  String get promiseLocal => 'Your photos and records never leave your phone.';

  @override
  String get promiseLearn =>
      'Suggestions are just the app\'s first pass. Change them anytime.';

  @override
  String get promiseRestore =>
      'Photos moved to trash can be restored from your gallery\'s trash for 30 days.';

  @override
  String get allowAccess => 'Allow photo and video access';

  @override
  String get allowInSettings => 'Allow in Settings';

  @override
  String get billingPending => 'Confirming your purchase…';

  @override
  String get billingFailed => 'The purchase didn\'t go through';

  @override
  String get billingUnavailable => 'Can\'t reach the store right now';

  @override
  String get billingDemo => 'Preview only — no real payment';

  @override
  String get proChip => 'Pro';

  @override
  String get proTitle => 'Mehh Pro';

  @override
  String get proBody => 'See picks for every set right away';

  @override
  String proFree(int limit, int count, String date) {
    return 'Without Pro: ◉ 1 per set · $limit a month · $count left · refills $date';
  }

  @override
  String get proActive => 'You have Pro. Every set\'s picks are open.';

  @override
  String get planLifetime => 'Lifetime';

  @override
  String get planLifetimeNote => 'Pay once, keep it';

  @override
  String get planYearly => '1 year';

  @override
  String get planYearlyNote => 'Renews yearly · cancel anytime';

  @override
  String get planBest => 'Best value';

  @override
  String get proNotes => 'No sign-up · new phone? tap Restore purchases';

  @override
  String get restorePurchases => 'Restore purchases';

  @override
  String get restored => 'Purchases restored';

  @override
  String get nothingToRestore => 'No purchases to restore';

  @override
  String get proThanks => 'Pro is unlocked';

  @override
  String proNudge(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Moved $countString photos to trash · restore them within 30 days, or empty the trash to free up space.',
      one: 'Moved 1 photo to trash · restore it within 30 days, or empty the trash to free up space.',
    );
    return '$_temp0 See picks for the other sets right away?';
  }

  @override
  String get contact => 'Contact us';

  @override
  String contactSubject(String version) {
    return 'Mehh feedback ($version)';
  }

  @override
  String contactNote(String email) {
    return '$email · No photos or records are sent automatically — only what you write.';
  }

  @override
  String get contactCopied => 'Email address copied';

  @override
  String get accTitle => 'Pick accuracy';

  @override
  String get accEmpty =>
      'No records yet. Clean up a set and tap Move to trash.';

  @override
  String get accRate => 'Picks you accepted';

  @override
  String accSends(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Moved to trash $count times',
      one: 'Moved to trash once',
    );
    return '$_temp0';
  }

  @override
  String accAccepted(int count, int total) {
    return 'Sent $count of $total photos the app picked';
  }

  @override
  String accAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos you picked that the app missed',
      one: '1 photo you picked that the app missed',
    );
    return '$_temp0';
  }

  @override
  String get accBest => 'Best shots you kept';

  @override
  String get accByTag => 'By reason';

  @override
  String accTagLine(int count, int total) {
    return '$count/$total';
  }

  @override
  String get accNote =>
      'These records stay on this phone. Above 80% for day sets, it\'s worth turning on payments.';

  @override
  String get cortexMultiUnsupported =>
      'Cortex can\'t take several at once yet. Please update Cortex.';

  @override
  String showPicks(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Show picks · $countString';
  }

  @override
  String get keepBarSemantics => 'Keep. You can also swipe the photo down';

  @override
  String get lookingAtPhotos => 'Looking through\nyour photos';

  @override
  String get duplicatesPending =>
      'We\'ll show exact duplicates once we\'ve looked at everything · Free';

  @override
  String get nothingMarked => 'Nothing to clean up';

  @override
  String yearlyEnded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Your 1-year plan ended · sets whose picks you saw stay open; new sets open with your ◉ $count this month',
      one: 'Your 1-year plan ended · sets whose picks you saw stay open; new sets open with your ◉ 1 this month',
    );
    return '$_temp0';
  }

  @override
  String get proUsing => 'You have Pro';

  @override
  String get privacyCortex =>
      'Photos and screenshots you send to Cortex are analyzed by Cortex\'s AI. Only the ones marked X, only when you tap \"To Cortex\".';

  @override
  String cortexNotSaved(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Cortex didn\'t confirm it got them, so nothing was moved to trash · your marks are kept. If you see them in Cortex, tap Move $countString to trash.',
      one: 'Cortex didn\'t confirm it got it, so nothing was moved to trash · your mark is kept. If you see it in Cortex, tap Move 1 to trash.',
    );
    return '$_temp0';
  }

  @override
  String get tagOldShot => 'Old';

  @override
  String get tagRepeatShot => 'Repeat';

  @override
  String get noteOldShot => 'Over 90 days old';

  @override
  String get noteRepeatShot => 'You took the same screen again right after';

  @override
  String accMuted(String names) {
    return 'Reasons paused for now (you often undid them, last 30 days): $names';
  }

  @override
  String get privacyPolicy => 'Privacy policy';

  @override
  String get termsRefunds => 'Terms & refunds';

  @override
  String get noticeAskTitle => 'Remind you when your coins are back?';

  @override
  String noticeAskBody(String date, int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString coins come back on $date',
      one: '1 coin comes back on $date',
    );
    return '$_temp0\nJust once, on the 1st of each month · turn it off in Settings';
  }

  @override
  String get noticeAskYes => 'Remind me';

  @override
  String get noticeAskNo => 'No thanks';

  @override
  String get noticeOn => 'We\'ll remind you on the 1st of each month';

  @override
  String get noticeBlocked =>
      'Notifications for Mehh are off in your phone settings';

  @override
  String get noticeSetting => 'Monthly reminder';

  @override
  String noticeSettingSubCoins(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Tells you on the 1st that $countString ◉ are back';
  }

  @override
  String get noticeSettingSubSets =>
      'Tells you on the 1st that last month\'s photo sets are waiting';

  @override
  String noticeCoinsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Your $count coins for this month are back',
      one: 'Your 1 coin for this month is back',
    );
    return '$_temp0';
  }

  @override
  String get noticeCoinsBody => 'See suggestions for last month\'s photo sets';

  @override
  String get noticeSetsTitle => 'Last month\'s photo sets are ready';

  @override
  String get noticeProBody =>
      'See suggestions and move them to trash in one go';

  @override
  String cortexPartial(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Cortex reported getting only $count · nothing was moved to trash · your marks are kept.',
      one: 'Cortex reported getting only 1 · nothing was moved to trash · your marks are kept.',
      zero: 'Cortex didn\'t report getting any · nothing was moved to trash · your marks are kept.',
    );
    return '$_temp0';
  }

  @override
  String get accByKind => 'By kind (day sets are the paid part)';

  @override
  String get kindDay => 'Day sets';

  @override
  String get proFreeKinds =>
      'Screenshots, singles and duplicates are always free';

  @override
  String freeRefilled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Your ◉ $count for this month are back',
      one: 'Your ◉ 1 for this month is back',
    );
    return '$_temp0';
  }

  @override
  String freeTodoShots(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Free right now: see $countString screenshot picks ›';
  }

  @override
  String freeTodoDuplicates(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Free right now: see $countString exact duplicates ›';
  }

  @override
  String get accRateDay => 'Day-set picks you accepted (the paid part)';

  @override
  String accRateAll(String rate) {
    return 'All kinds together $rate (for reference)';
  }

  @override
  String get mutedBurst =>
      'You often keep similar shots, so we\'ll stop suggesting them for now · we\'ll try again in 30 days';

  @override
  String get mutedBlurry =>
      'You often keep blurry shots, so we\'ll stop suggesting them for now · we\'ll try again in 30 days';

  @override
  String get mutedJunk =>
      'You often keep accidental shots, so we\'ll stop suggesting them for now · we\'ll try again in 30 days';

  @override
  String get useFreeSetTitle => 'Open with 1?';

  @override
  String useFreeSetBody(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'See $countString picks. Once opened, it stays open.',
      one: 'See 1 pick. Once opened, it stays open.',
    );
    return '$_temp0';
  }

  @override
  String get useFreeSetYes => 'Open';

  @override
  String get toCortex => 'To Cortex';

  @override
  String cortexAskTitle(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Send $countString to Cortex?',
      one: 'Send 1 to Cortex?',
    );
    return '$_temp0';
  }

  @override
  String get cortexAskYes => 'Send';

  @override
  String noFreeLead(String date, int count) {
    return '◉ 0 left this month · $count more on $date';
  }

  @override
  String get cortexSentBadge => 'Sent to Cortex';

  @override
  String cortexGotTitle(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '✓ Cortex got $countString',
      one: '✓ Cortex got 1',
    );
    return '$_temp0';
  }

  @override
  String get cortexGotBody =>
      'Cortex analyzes them in the background. You can close the app.\nMove these photos to trash?';

  @override
  String cortexGotKept(int kept) {
    final intl.NumberFormat keptNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String keptString = keptNumberFormat.format(kept);

    String _temp0 = intl.Intl.pluralLogic(
      kept,
      locale: localeName,
      other: '$keptString Cortex didn\'t get stay as is.',
      one: '1 Cortex didn\'t get stays as is.',
    );
    return '$_temp0';
  }

  @override
  String cortexGotUnmarked(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'The $countString you switched to keep stay as is.',
      one: 'The 1 you switched to keep stays as is.',
    );
    return '$_temp0';
  }

  @override
  String sendLimitLeft(int count, int left) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);
    final intl.NumberFormat leftNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String leftString = leftNumberFormat.format(left);

    String _temp0 = intl.Intl.pluralLogic(
      left,
      locale: localeName,
      other:
          'Up to $countString at a time, so $leftString more stay marked. Tap again to send them.',
      one:
          'Up to $countString at a time, so 1 more stays marked. Tap again to send it.',
    );
    return '$_temp0';
  }

  @override
  String get later => 'Later';

  @override
  String get focusFinishNone => 'Nothing to clean up. Finish?';

  @override
  String get focusKeepLooking => 'Keep looking';

  @override
  String get focusFinishYes => 'Finish';

  @override
  String focusPosition(int current, int total) {
    final intl.NumberFormat currentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String currentString = currentNumberFormat.format(current);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$currentString / $totalString';
  }

  @override
  String get focusHint => 'Press and hold to finish';

  @override
  String get focusFinishSemantics => 'Finish sorting';

  @override
  String barPhotos(Object size) {
    return 'Photos & videos $size';
  }

  @override
  String barSent(Object size) {
    return 'Trash $size';
  }

  @override
  String barSelected(Object size) {
    return 'Selected $size';
  }

  @override
  String get openGallery => 'Gallery';

  @override
  String get noGallery => 'Couldn\'t find a gallery app';

  @override
  String coinCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count coins',
      one: '1 coin',
    );
    return '$_temp0';
  }

  @override
  String get picksDot => 'Suggested cleanup left';

  @override
  String picksOn(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString picks on';
  }

  @override
  String get barRecommendedLabel => 'Suggested ';

  @override
  String get tagEyesClosed => 'Eyes closed';

  @override
  String get noteEyesClosed =>
      'Eyes closed · another shot of the same moment has them open';

  @override
  String get mutedEyesClosed =>
      'You often keep eyes-closed shots, so we\'ll skip them for now · we\'ll try again in 30 days';

  @override
  String get testFreeChip => 'Free in testing';

  @override
  String get renameTitle => 'Set name';

  @override
  String get renameReset => 'Original name';

  @override
  String get save => 'Save';

  @override
  String get privacyShortLocal => 'Photos and records stay on this phone';

  @override
  String get privacyShortPlace =>
      'Place names use only the location, via your phone\'s location service';

  @override
  String get privacyShortFaces => 'Closed-eye checks happen on your phone only';

  @override
  String get privacyShortTrash => 'Trashed photos can be restored for 30 days';

  @override
  String get privacyShortCortex =>
      'Only photos marked X go to Cortex, only when you tap \"To Cortex\" (Cortex analyzes them with AI)';

  @override
  String get helpTitle => 'Help';

  @override
  String get clearAllSub => 'Clears analysis and records · your photos stay';

  @override
  String get coinWord => 'coin';

  @override
  String get bigVideos => 'Big videos';

  @override
  String videosMeta(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videos · $size',
      one: '1 video · $size',
    );
    return '$_temp0';
  }

  @override
  String get cortexAskNote => 'Cortex analyzes them with AI';

  @override
  String get cortexGetTitle => 'You need Cortex';

  @override
  String get cortexGetBody =>
      'Cortex turns photos and screenshots into notes. Install it, then tap To Cortex again.';

  @override
  String get cortexGetYes => 'Get Cortex';

  @override
  String videosCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString videos',
      one: '1 video',
    );
    return '$_temp0';
  }

  @override
  String trashCountVideos(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Move $countString videos to trash',
      one: 'Move 1 video to trash',
    );
    return '$_temp0';
  }

  @override
  String trashedVideos(int count, String size) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '✓ $countString videos · $size moved to trash · restore them within 30 days, or empty the trash to free up that space',
      one:
          '✓ 1 video · $size moved to trash · restore it within 30 days, or empty the trash to free up that space',
    );
    return '$_temp0';
  }

  @override
  String get nothingMarkedVideos => 'No videos selected';

  @override
  String get focusFinishNoneVideos => 'No videos selected. Finish?';

  @override
  String get proTestFree =>
      'During the closed test, picks for every set are free';

  @override
  String get proAtLaunch => 'Pro will be available at launch';

  @override
  String cortexAskResend(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Includes $countString already sent to Cortex',
      one: 'Includes 1 already sent to Cortex',
    );
    return '$_temp0';
  }

  @override
  String proOnPhone(int groups, int count, String size) {
    final intl.NumberFormat groupsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String groupsString = groupsNumberFormat.format(groups);
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      groups,
      locale: localeName,
      other: '$groupsString locked sets',
      one: '1 locked set',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString picks',
      one: '1 pick',
    );
    return 'On this phone: $_temp0 · $_temp1 · about $size';
  }

  @override
  String shotsReadyNow(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString screenshots are ready to clean up now ›',
      one: '1 screenshot is ready to clean up now ›',
    );
    return '$_temp0';
  }

  @override
  String get playVideo => 'Play';

  @override
  String get videoOpenFailed => 'Couldn\'t find an app to play this video';

  @override
  String testEnded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'The closed test is over · ◉ $count this month',
      one: 'The closed test is over · ◉ 1 this month',
    );
    return '$_temp0';
  }

  @override
  String get noAllowedPhotos => 'No photos allowed yet';
}
