// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get cancel => 'Cancel';

  @override
  String get undo => 'Undo';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get add => 'Add';

  @override
  String get name => 'Name';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get catGroceries => 'Groceries';

  @override
  String get catRestaurants => 'Restaurants & bars';

  @override
  String get catTransport => 'Transport';

  @override
  String get catHome => 'Home & bills';

  @override
  String get catHealth => 'Health';

  @override
  String get catShopping => 'Shopping';

  @override
  String get catLeisure => 'Leisure';

  @override
  String get catOther => 'Other';

  @override
  String get accountCard => 'Card';

  @override
  String get accountCash => 'Cash';

  @override
  String get accountOther => 'Other';

  @override
  String get navSummary => 'Summary';

  @override
  String get navTransactions => 'Transactions';

  @override
  String get navCategories => 'Categories';

  @override
  String get addScanTitle => 'Photograph a receipt';

  @override
  String get addScanSubtitle => 'Amount, date and shop read automatically';

  @override
  String get addGalleryTitle => 'Choose from gallery';

  @override
  String get addGallerySubtitle => 'Use a photo of a receipt you already took';

  @override
  String get addManualTitle => 'Enter manually';

  @override
  String get addManualSubtitle => 'For expenses without a receipt, e.g. cash';

  @override
  String get previousMonth => 'Previous month';

  @override
  String get nextMonth => 'Next month';

  @override
  String get receiptTitle => 'Receipt';

  @override
  String get scanPreparing => 'Getting the reader ready…';

  @override
  String get scanReading => 'Reading the receipt…';

  @override
  String get scanOffline => 'Everything happens on your phone, offline.';

  @override
  String get scanFailed => 'Couldn\'t read the receipt';

  @override
  String get scanWarnNoText =>
      'No text found: try a sharper, straighter photo.';

  @override
  String get scanWarnNoTotal => 'Total not found: enter it manually.';

  @override
  String get scanWarnNoMerchant => 'Shop not found.';

  @override
  String expenseDeleted(String amount) {
    return 'Expense deleted: $amount';
  }

  @override
  String get searchHint => 'Search shop, note, category';

  @override
  String get noTransactionsTitle => 'No transactions';

  @override
  String get noTransactionsMessage =>
      'Expenses you add will appear here, grouped by day.';

  @override
  String get noResultsTitle => 'No results';

  @override
  String get noResultsMessage => 'Try changing the search or filters.';

  @override
  String get chooseCategory => 'Choose a category';

  @override
  String get expenseUpdated => 'Expense updated';

  @override
  String get expenseSaved => 'Expense saved';

  @override
  String expenseSavedIn(DateTime month) {
    final intl.DateFormat monthDateFormat = intl.DateFormat.yMMMM(localeName);
    final String monthString = monthDateFormat.format(month);

    return 'Expense saved in $monthString';
  }

  @override
  String get deleteExpenseTitle => 'Delete this expense?';

  @override
  String get deleteExpenseMessage =>
      'The expense and the receipt photo will be deleted.';

  @override
  String get editExpense => 'Edit expense';

  @override
  String get checkReceipt => 'Check the receipt';

  @override
  String get newExpense => 'New expense';

  @override
  String get amount => 'Amount';

  @override
  String get enterAmount => 'Enter an amount';

  @override
  String get merchant => 'Shop';

  @override
  String get merchantHint => 'E.g. Tesco, Corner Café';

  @override
  String get category => 'Category';

  @override
  String get paidWith => 'Paid with';

  @override
  String get dateNotFound => 'Date not found on the receipt';

  @override
  String get noteOptional => 'Note (optional)';

  @override
  String get suggestedLearned => 'Suggested: you used it before for this shop';

  @override
  String suggestedKeyword(String word) {
    return 'Suggested by the word \"$word\"';
  }

  @override
  String suggestedKeywordReceipt(String word) {
    return 'Suggested by the word \"$word\" on the receipt';
  }

  @override
  String get receiptText => 'Text read from the receipt';

  @override
  String budgetNear(String category, int percent, String left) {
    return '$category: $percent% of the limit used, $left left';
  }

  @override
  String budgetExhausted(String category) {
    return '$category: monthly limit used up';
  }

  @override
  String budgetOver(String category, String over) {
    return '$category: $over over the limit';
  }

  @override
  String budgetReachedTitle(String category) {
    return '$category limit reached';
  }

  @override
  String budgetReachedExact(String limit) {
    return 'This month you spent exactly your limit of $limit.';
  }

  @override
  String budgetReachedOver(String spent, String limit, String over) {
    return 'This month you spent $spent against a limit of $limit: $over over.';
  }

  @override
  String get gotIt => 'Got it';

  @override
  String get summaryTitle => 'Monthly summary';

  @override
  String get settings => 'Settings';

  @override
  String get noSpendingTitle => 'No expenses this month';

  @override
  String get noSpendingMessage =>
      'Tap \"Add\" to photograph a receipt or enter an expense manually.';

  @override
  String get spentThisMonth => 'Spent this month';

  @override
  String sameAsMonth(String prep, DateTime month) {
    final intl.DateFormat monthDateFormat = intl.DateFormat.MMMM(localeName);
    final String monthString = monthDateFormat.format(month);

    return 'Same as $monthString';
  }

  @override
  String percentVsMonth(String change, String prep, DateTime month) {
    final intl.DateFormat monthDateFormat = intl.DateFormat.MMMM(localeName);
    final String monthString = monthDateFormat.format(month);

    return '$change% vs $monthString';
  }

  @override
  String amountVsMonth(String change, String prep, DateTime month) {
    final intl.DateFormat monthDateFormat = intl.DateFormat.MMMM(localeName);
    final String monthString = monthDateFormat.format(month);

    return '$change vs $monthString';
  }

  @override
  String nothingInMonth(String prep, DateTime month) {
    final intl.DateFormat monthDateFormat = intl.DateFormat.MMMM(localeName);
    final String monthString = monthDateFormat.format(month);

    return 'Nothing in $monthString';
  }

  @override
  String get last6Months => 'Last 6 months';

  @override
  String get byCategory => 'By category';

  @override
  String get legendLimit => 'limit';

  @override
  String remaining(String amount) {
    return '$amount left';
  }

  @override
  String get limitExhausted => 'Limit used up';

  @override
  String overBy(String amount) {
    return 'Over by $amount';
  }

  @override
  String get recentTransactions => 'Recent transactions';

  @override
  String get seeAll => 'See all';

  @override
  String get newCategory => 'New category';

  @override
  String get editCategory => 'Edit category';

  @override
  String categoriesIntro(DateTime month) {
    final intl.DateFormat monthDateFormat = intl.DateFormat.yMMMM(localeName);
    final String monthString = monthDateFormat.format(month);

    return 'Totals for $monthString. Tap a category to change its name, icon, colour or the words used to recognise it on receipts.';
  }

  @override
  String expenseCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count expenses',
      one: '1 expense',
      zero: 'No expenses',
    );
    return '$_temp0';
  }

  @override
  String monthlyLimitPerMonth(String amount) {
    return 'Limit $amount per month';
  }

  @override
  String get limitInvalid => 'Enter an amount, e.g. 100';

  @override
  String get onlyCategory =>
      'It\'s the only category: create another one before deleting it';

  @override
  String deleteCategoryTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get categoryEmpty => 'There are no expenses in this category.';

  @override
  String moveExpensesTo(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name has $count expenses. Move them to:',
      one: '$name has 1 expense. Move it to:',
    );
    return '$_temp0';
  }

  @override
  String get moveAndDelete => 'Move and delete';

  @override
  String get monthlyLimitLabel => 'Monthly limit (optional)';

  @override
  String get monthlyLimitHelper =>
      'You\'ll be warned at 80% and when you reach it. Leave empty for no limit.';

  @override
  String get icon => 'Icon';

  @override
  String get color => 'Colour';

  @override
  String get keywords => 'Keywords';

  @override
  String get keywordsHelper =>
      'Words that appear on receipts, separated by commas (e.g. pharmacy, chemist). They help with shops you\'ve never used: for the others the app remembers your choice.';

  @override
  String get sectionAppearance => 'Appearance';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get appLanguage => 'App language';

  @override
  String get languageSystem => 'System';

  @override
  String get languageItalian => 'Italiano';

  @override
  String get languageEnglish => 'English';

  @override
  String get accentGreen => 'Green';

  @override
  String get accentBlue => 'Blue';

  @override
  String get accentPurple => 'Purple';

  @override
  String get accentPink => 'Pink';

  @override
  String get accentOrange => 'Orange';

  @override
  String get accentGraphite => 'Graphite';

  @override
  String get sectionSecurity => 'Security';

  @override
  String get changePassword => 'Change password';

  @override
  String get currentPassword => 'Current password';

  @override
  String get newPassword => 'New password';

  @override
  String get repeatNewPassword => 'Repeat the new password';

  @override
  String get newPasswordTooShort =>
      'The new password must be at least 4 characters';

  @override
  String get newPasswordsMismatch => 'The new passwords don\'t match';

  @override
  String get currentPasswordWrong => 'The current password is wrong';

  @override
  String get passwordChanged => 'Password changed';

  @override
  String get biometricUnlock => 'Unlock with fingerprint';

  @override
  String get biometricKeepsPassword => 'Your password always keeps working';

  @override
  String get biometricNone => 'No fingerprint registered on this phone';

  @override
  String get sectionReceipts => 'Receipts';

  @override
  String get receiptLanguage => 'Receipt language';

  @override
  String get receiptLanguageHint =>
      'Changes the words the reader looks for to find the total and date';

  @override
  String get receiptLangItalian => 'Italian';

  @override
  String get receiptLangEnglish => 'English';

  @override
  String get tryReader => 'Try the reader';

  @override
  String get tryReaderHint =>
      'Shows the text it reads and the boxes, without saving anything';

  @override
  String get sectionAccounts => 'Accounts';

  @override
  String get addAccount => 'Add account';

  @override
  String get newAccount => 'New account';

  @override
  String get editAccount => 'Edit account';

  @override
  String get accountNameHint => 'E.g. Prepaid card';

  @override
  String get archive => 'Archive';

  @override
  String get sectionData => 'Data';

  @override
  String get dataStaysOnPhone => 'Everything stays on your phone';

  @override
  String get dataStaysOnPhoneHint =>
      'Expenses, photos and receipt reading never leave the device.';

  @override
  String get exportData => 'Export data';

  @override
  String get exportDataHint =>
      'Database and photos in a .zip file to save wherever you like, e.g. on Drive. The file is not encrypted.';

  @override
  String get exportShareTitle => 'Export Receipt data';

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get importBackup => 'Import from backup';

  @override
  String get importBackupHint =>
      'Restores from a zip made with \"Export data\". Replaces the current data.';

  @override
  String get chooseBackup => 'Choose the backup (.zip)';

  @override
  String get restoreTitle => 'Restore the backup?';

  @override
  String restoreSummary(int expenses, int photos) {
    String _temp0 = intl.Intl.pluralLogic(
      expenses,
      locale: localeName,
      other: '$expenses expenses',
      one: '1 expense',
    );
    String _temp1 = intl.Intl.pluralLogic(
      photos,
      locale: localeName,
      other: '$photos photos',
      one: '1 photo',
    );
    return 'Backup: $_temp0, $_temp1.';
  }

  @override
  String restoreSummaryDated(DateTime date, int expenses, int photos) {
    final intl.DateFormat dateDateFormat = intl.DateFormat(
      'd MMMM y, HH:mm',
      localeName,
    );
    final String dateString = dateDateFormat.format(date);

    String _temp0 = intl.Intl.pluralLogic(
      expenses,
      locale: localeName,
      other: '$expenses expenses',
      one: '1 expense',
    );
    String _temp1 = intl.Intl.pluralLogic(
      photos,
      locale: localeName,
      other: '$photos photos',
      one: '1 photo',
    );
    return 'Backup from $dateString: $_temp0, $_temp1.';
  }

  @override
  String restoreReplaceWarning(int current) {
    String _temp0 = intl.Intl.pluralLogic(
      current,
      locale: localeName,
      other: '$current expenses',
      one: '1 expense',
    );
    return 'All current data ($_temp0, categories, accounts, limits) will be replaced. If you want to keep it, export it first.';
  }

  @override
  String get replace => 'Replace';

  @override
  String restoreDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Data restored: $count expenses',
      one: 'Data restored: 1 expense',
    );
    return '$_temp0';
  }

  @override
  String restoreFailed(String error) {
    return 'Restore failed: $error';
  }

  @override
  String get backupNotZip => 'The file is not a valid zip.';

  @override
  String get backupNotReceipt => 'This zip is not a Receipt backup.';

  @override
  String get backupDamaged => 'The backup is damaged (unreadable manifest).';

  @override
  String get backupNewer =>
      'The backup comes from a newer version of the app: update Receipt and try again.';

  @override
  String get autoBackup => 'Encrypted automatic backup';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get loadDemo => 'Load demo data';

  @override
  String get loadDemoHint =>
      'Made-up expenses in October and September 2026, with some limits';

  @override
  String get hidePassword => 'Hide';

  @override
  String get showPassword => 'Show';

  @override
  String get passwordTooShort => 'At least 4 characters';

  @override
  String get passwordsMismatch => 'Passwords don\'t match';

  @override
  String get useBiometricTitle => 'Use your fingerprint?';

  @override
  String get useBiometricMessage =>
      'You can open Receipt with your fingerprint instead of typing the password every time. The password stays valid and you can always use it.';

  @override
  String get useBiometric => 'Use fingerprint';

  @override
  String get notNow => 'Not now';

  @override
  String get setupTitle => 'Protect your expenses';

  @override
  String get setupMessage =>
      'Choose a password to open Receipt. There\'s no way to recover it: remember it or save it in your password manager.';

  @override
  String get password => 'Password';

  @override
  String get repeatPassword => 'Repeat the password';

  @override
  String get continueLabel => 'Continue';

  @override
  String get wrongPassword => 'Wrong password';

  @override
  String get lockedTitle => 'Receipt is locked';

  @override
  String get lockedMessage => 'Enter your password to continue.';

  @override
  String tooManyAttempts(int seconds) {
    return 'Too many attempts: try again in $seconds s';
  }

  @override
  String get unlock => 'Unlock';

  @override
  String get biometricPromptUnlock => 'Unlock Receipt';

  @override
  String get biometricPromptConfirm =>
      'Confirm your fingerprint to unlock Receipt';

  @override
  String get biometricUsePassword => 'Use password';

  @override
  String get ocrTitle => 'Receipt reader';

  @override
  String get copyText => 'Copy text';

  @override
  String get textCopied => 'Text copied';

  @override
  String get takePhoto => 'Camera';

  @override
  String get gallery => 'Gallery';

  @override
  String get ocrIntro =>
      'The text is read with RapidOCR right on your phone, offline.';

  @override
  String ocrLines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lines',
      one: '1 line',
    );
    return '$_temp0';
  }

  @override
  String get ocrBoxes => 'Boxes';

  @override
  String updateAvailable(String version, String size) {
    return 'Receipt $version is available ($size)';
  }

  @override
  String get updateLater => 'Not now';

  @override
  String get updateNow => 'Update';

  @override
  String updateTitle(String version) {
    return 'Update to $version';
  }

  @override
  String get updateDownloading => 'Downloading the update…';

  @override
  String updateProgress(String done, String total) {
    return '$done of $total';
  }

  @override
  String get updatePermission =>
      'To install the update, Android asks you to allow Receipt to install apps. You only need to do this once.';

  @override
  String get updateAllow => 'Allow';

  @override
  String get updateInstalling =>
      'The Android installer opens: tap “Update” to finish. Your expenses and photos stay where they are.';

  @override
  String get updateErrorNetwork =>
      'Download failed. Check your connection and try again.';

  @override
  String get updateErrorCorrupted =>
      'The downloaded file does not match the published one and was discarded. Try again.';

  @override
  String get retry => 'Retry';

  @override
  String get close => 'Close';

  @override
  String get sectionUpdates => 'Updates';

  @override
  String get updateCheckOnStart => 'Check at startup';

  @override
  String get updateCheckOnStartHint =>
      'Reads the available version from the Receipt website. None of your data is sent.';

  @override
  String get updateCheckNow => 'Check now';

  @override
  String updateInstalledVersion(String version) {
    return 'Installed version: $version';
  }

  @override
  String get updateUpToDate => 'You already have the latest version';

  @override
  String get updateCheckFailed => 'Can\'t check for updates: are you online?';

  @override
  String get scanRecovered =>
      'Android closed Receipt while you were taking the photo: here it is, reading it now.';

  @override
  String get chooseMonth => 'Go to month';

  @override
  String get thisMonth => 'This month';

  @override
  String get previousYear => 'Previous year';

  @override
  String get nextYear => 'Next year';

  @override
  String get updateConsentTitle => 'Automatic updates';

  @override
  String get updateConsentMessage =>
      'Receipt runs entirely on your phone and does not collect your data. Should it check online for a new version every time it opens? It only reads the version number from the Receipt website. You can change your mind in Settings.';

  @override
  String get updateConsentNo => 'No, thanks';

  @override
  String get updateConsentYes => 'Yes, check';

  @override
  String get dailyArt => 'Painting of the day';

  @override
  String get dailyArtHint =>
      'A painting from The Metropolitan Museum of Art as the background, a new one every day out of 600 in the public domain. Downloads one image a day from Wikimedia Commons (about 0.7 MB); none of your data is sent.';

  @override
  String get dailyArtDownloading => 'Downloading today\'s painting…';

  @override
  String get dailyArtFailed =>
      'Couldn\'t download today\'s painting: I\'ll try again when you come back to the app.';

  @override
  String dailyArtToday(String title, String artist) {
    return 'Today: $title, $artist. Tap the “i” at the top to learn more.';
  }

  @override
  String get paintingOfTheDay => 'Today\'s painting';

  @override
  String get paintingDate => 'Date';

  @override
  String get paintingMedium => 'Medium';

  @override
  String get paintingDimensions => 'Dimensions';

  @override
  String paintingCredit(String credit) {
    return 'The Metropolitan Museum of Art, New York. $credit';
  }

  @override
  String get paintingOpenMet => 'The Met\'s page';

  @override
  String paintingFromWikipedia(String title) {
    return 'From Wikipedia, article “$title” (CC BY-SA 4.0)';
  }

  @override
  String get paintingFromWikidata => 'From Wikidata (CC0)';

  @override
  String paintingSources(String license) {
    return 'Artwork data: The Met Open Access and Wikidata (CC0). Image: Wikimedia Commons ($license).';
  }

  @override
  String get paintingOpenWikipedia => 'Wikipedia';

  @override
  String get paintingOpenCommons => 'Image on Commons';

  @override
  String get dailyArtConsentMessage =>
      'Would you like a painting from The Metropolitan Museum of Art as the background, a different one every day? Receipt downloads one image a day from Wikimedia Commons (about 0.7 MB) and sends none of your data. You can change your mind in Settings.';

  @override
  String get dailyArtConsentInternet =>
      'You chose not to let Receipt use the internet for updates. The painting of the day needs the internet: if you turn it on, the app will connect only to download today\'s image.';

  @override
  String get dailyArtConsentYes => 'Yes, turn it on';

  @override
  String dailyArtVisibility(String percent) {
    return 'Painting visibility: $percent%';
  }
}
