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
  String get undo => 'Undo';

  @override
  String get reset => 'Start over';

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
    return 'Freed $size this month';
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
  String summaryJunk(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count accidental shots',
      one: '1 accidental shot',
    );
    return '$_temp0';
  }

  @override
  String summaryBlurry(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count blurry shots with sharper ones',
      one: '1 blurry shot with a sharper one',
    );
    return '$_temp0';
  }

  @override
  String summaryBurst(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count similar shots',
      one: '1 similar shot',
    );
    return '$_temp0';
  }

  @override
  String get summaryDuplicates =>
      'Marked the duplicates, keeping one in each set';

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
  String get sendToCortex => 'Send to Cortex';

  @override
  String get cortexSent => 'Sent to Cortex · marked for removal';

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
  String get resetTitle => 'Reset to the original picks?';

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
  String get analyzingTitle => 'Analyzing your photos';

  @override
  String get analyzingDetail => 'Suggestions will fill in as we go.';

  @override
  String get noneFound => 'Nothing to clean up here';

  @override
  String get willRemoveSuffix => ' to remove';

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
          'Moved $countString photos to trash · restore them from your gallery\'s trash within 30 days',
      one: 'Moved 1 photo to trash · restore it from your gallery\'s trash within 30 days',
    );
    return '$_temp0';
  }

  @override
  String get clearTitle => 'Clear all records?';

  @override
  String get clearBody =>
      'This clears photo analysis, keep/remove records, and space-freed history.\nYour photos aren\'t deleted.';

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
  String get allKept => 'Keeping all of them';

  @override
  String unlockTitle(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Picked $countString photos to remove',
      one: 'Picked 1 photo to remove',
    );
    return '$_temp0';
  }

  @override
  String get unlockButton => 'See picks · 1 credit';

  @override
  String get unlockHint => 'Marking photos yourself is free';

  @override
  String creditsLeft(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString credits left',
      one: '1 credit left',
    );
    return '$_temp0';
  }

  @override
  String get creditsBuy => 'Get credits';

  @override
  String creditsChip(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString credits',
      one: '1 credit',
    );
    return '$_temp0';
  }

  @override
  String get creditsTitle => 'Credits';

  @override
  String get creditsBody =>
      'Seeing the picks for one set uses 1 credit. Once opened, a set stays open.';

  @override
  String get creditsFree =>
      'Duplicates, single shots, screenshots and marking photos yourself are free.';

  @override
  String get creditsNotes =>
      'No sign-up — credits are stored only on this phone. They never expire, but they\'re lost if you delete the app.';

  @override
  String packCredits(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString credits';
  }

  @override
  String creditsAdded(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added $countString credits',
      one: 'Added 1 credit',
    );
    return '$_temp0';
  }

  @override
  String get billingPending => 'Confirming your purchase…';

  @override
  String get billingFailed => 'The purchase didn\'t go through';

  @override
  String get billingUnavailable => 'Can\'t reach the store right now';

  @override
  String get billingDemo => 'Preview only — no real payment';
}
