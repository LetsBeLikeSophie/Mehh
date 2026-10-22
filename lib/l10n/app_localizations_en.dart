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
      'You marked every similar photo. Move them to trash anyway?';

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
  String trashed(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Moved $countString photos to trash · restore them within 30 days, or empty the trash to free up space',
      one: 'Moved 1 photo to trash · restore it within 30 days, or empty the trash to free up space',
    );
    return '$_temp0';
  }

  @override
  String get clearTitle => 'Clear all records?';

  @override
  String get clearBody =>
      'This clears photo analysis, keep/remove records, and trashed-size history.\nYour photos aren\'t deleted.';

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
      'To group photos by date and place and find duplicates, Mehh needs access to all your photos.';

  @override
  String get promiseLocal => 'Your photos and records never leave your phone.';

  @override
  String get promiseLearn =>
      'Suggestions are just the app\'s first pass. Change them anytime.';

  @override
  String get promiseRestore =>
      'Photos moved to trash can be restored from your gallery\'s trash for 30 days.';

  @override
  String get allowAccess => 'Allow photo access';

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
  String freeChip(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString free sets',
      one: '1 free set',
    );
    return '$_temp0';
  }

  @override
  String get proTitle => 'Mehh Pro';

  @override
  String get proBody => 'See the picks for every set, right away.';

  @override
  String proFree(int limit, int count, String date) {
    return 'Free: picks for $limit sets each month. $count left this month, back to $limit on $date.';
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
  String get proNotes =>
      'No sign-up — you buy with your store account. On a new phone or after reinstalling, tap Restore purchases. The 1-year plan renews automatically each year until you cancel it in your store\'s subscriptions.';

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
      'These records stay on this phone. Above 80% accepted, the picks are trustworthy.';

  @override
  String cortexSendCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Send $countString to Cortex',
      one: 'Send 1 to Cortex',
    );
    return '$_temp0';
  }

  @override
  String get cortexThenTrash =>
      'Cortex sorts sent screenshots with AI · Mehh then moves them to trash';

  @override
  String cortexSentTrashed(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Sent $countString to Cortex and moved them to trash · restore within 30 days',
      one: 'Sent 1 to Cortex and moved it to trash · restore within 30 days',
    );
    return '$_temp0';
  }

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
  String freeLeftNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count free sets left this month',
      one: '1 free set left this month',
      zero: 'No free sets left this month',
    );
    return '$_temp0';
  }

  @override
  String get cortexSend => 'Send to Cortex';

  @override
  String get keepBarSemantics => 'Keep. You can also swipe the photo down';

  @override
  String picksCostNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Uses 1 of this month\'s free sets · $count left',
      one: 'Uses 1 of this month\'s free sets · 1 left',
    );
    return '$_temp0';
  }

  @override
  String picksNoFreeNote(String date, int count) {
    return 'No free sets left this month · $count more on $date';
  }

  @override
  String get lookingAtPhotos => 'Looking through\nyour photos';

  @override
  String get duplicatesPending =>
      'We\'ll show exact duplicates once we\'ve looked at everything · Free';

  @override
  String get nothingMarked => 'No photos marked';

  @override
  String yearlyEnded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Your 1-year plan ended · back to $count free sets this month',
      one: 'Your 1-year plan ended · back to 1 free set this month',
    );
    return '$_temp0';
  }

  @override
  String get proUsing => 'You have Pro';

  @override
  String freeSetsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count free sets left',
      one: '1 free set left',
    );
    return '$_temp0';
  }

  @override
  String earlierMarked(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString photos marked earlier',
      one: '1 photo marked earlier',
    );
    return '$_temp0';
  }
}
