import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
    Locale('it'),
  ];

  /// No description provided for @cancel.
  ///
  /// In it, this message translates to:
  /// **'Annulla'**
  String get cancel;

  /// No description provided for @undo.
  ///
  /// In it, this message translates to:
  /// **'Annulla'**
  String get undo;

  /// No description provided for @save.
  ///
  /// In it, this message translates to:
  /// **'Salva'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In it, this message translates to:
  /// **'Elimina'**
  String get delete;

  /// No description provided for @add.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi'**
  String get add;

  /// No description provided for @name.
  ///
  /// In it, this message translates to:
  /// **'Nome'**
  String get name;

  /// No description provided for @today.
  ///
  /// In it, this message translates to:
  /// **'Oggi'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In it, this message translates to:
  /// **'Ieri'**
  String get yesterday;

  /// No description provided for @catGroceries.
  ///
  /// In it, this message translates to:
  /// **'Spesa'**
  String get catGroceries;

  /// No description provided for @catRestaurants.
  ///
  /// In it, this message translates to:
  /// **'Ristoranti e bar'**
  String get catRestaurants;

  /// No description provided for @catTransport.
  ///
  /// In it, this message translates to:
  /// **'Trasporti'**
  String get catTransport;

  /// No description provided for @catHome.
  ///
  /// In it, this message translates to:
  /// **'Casa e bollette'**
  String get catHome;

  /// No description provided for @catHealth.
  ///
  /// In it, this message translates to:
  /// **'Salute'**
  String get catHealth;

  /// No description provided for @catShopping.
  ///
  /// In it, this message translates to:
  /// **'Shopping'**
  String get catShopping;

  /// No description provided for @catLeisure.
  ///
  /// In it, this message translates to:
  /// **'Svago'**
  String get catLeisure;

  /// No description provided for @catOther.
  ///
  /// In it, this message translates to:
  /// **'Altro'**
  String get catOther;

  /// No description provided for @accountCard.
  ///
  /// In it, this message translates to:
  /// **'Carta'**
  String get accountCard;

  /// No description provided for @accountCash.
  ///
  /// In it, this message translates to:
  /// **'Contanti'**
  String get accountCash;

  /// No description provided for @accountOther.
  ///
  /// In it, this message translates to:
  /// **'Altro'**
  String get accountOther;

  /// No description provided for @navSummary.
  ///
  /// In it, this message translates to:
  /// **'Riepilogo'**
  String get navSummary;

  /// No description provided for @navTransactions.
  ///
  /// In it, this message translates to:
  /// **'Movimenti'**
  String get navTransactions;

  /// No description provided for @navCategories.
  ///
  /// In it, this message translates to:
  /// **'Categorie'**
  String get navCategories;

  /// No description provided for @addScanTitle.
  ///
  /// In it, this message translates to:
  /// **'Fotografa uno scontrino'**
  String get addScanTitle;

  /// No description provided for @addScanSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Importo, data ed esercente letti in automatico'**
  String get addScanSubtitle;

  /// No description provided for @addGalleryTitle.
  ///
  /// In it, this message translates to:
  /// **'Scegli dalla galleria'**
  String get addGalleryTitle;

  /// No description provided for @addGallerySubtitle.
  ///
  /// In it, this message translates to:
  /// **'Usa una foto di uno scontrino già scattata'**
  String get addGallerySubtitle;

  /// No description provided for @addManualTitle.
  ///
  /// In it, this message translates to:
  /// **'Inserisci a mano'**
  String get addManualTitle;

  /// No description provided for @addManualSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Per spese senza scontrino, es. in contanti'**
  String get addManualSubtitle;

  /// No description provided for @previousMonth.
  ///
  /// In it, this message translates to:
  /// **'Mese precedente'**
  String get previousMonth;

  /// No description provided for @nextMonth.
  ///
  /// In it, this message translates to:
  /// **'Mese successivo'**
  String get nextMonth;

  /// No description provided for @receiptTitle.
  ///
  /// In it, this message translates to:
  /// **'Scontrino'**
  String get receiptTitle;

  /// No description provided for @scanPreparing.
  ///
  /// In it, this message translates to:
  /// **'Preparo il lettore…'**
  String get scanPreparing;

  /// No description provided for @scanReading.
  ///
  /// In it, this message translates to:
  /// **'Leggo lo scontrino…'**
  String get scanReading;

  /// No description provided for @scanOffline.
  ///
  /// In it, this message translates to:
  /// **'Tutto avviene sul telefono, senza connessione.'**
  String get scanOffline;

  /// No description provided for @scanFailed.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a leggere lo scontrino'**
  String get scanFailed;

  /// No description provided for @scanWarnNoText.
  ///
  /// In it, this message translates to:
  /// **'Non ho trovato testo: prova con una foto più nitida e dritta.'**
  String get scanWarnNoText;

  /// No description provided for @scanWarnNoTotal.
  ///
  /// In it, this message translates to:
  /// **'Totale non trovato: inseriscilo a mano.'**
  String get scanWarnNoTotal;

  /// No description provided for @scanWarnNoMerchant.
  ///
  /// In it, this message translates to:
  /// **'Esercente non trovato.'**
  String get scanWarnNoMerchant;

  /// No description provided for @expenseDeleted.
  ///
  /// In it, this message translates to:
  /// **'Spesa eliminata: {amount}'**
  String expenseDeleted(String amount);

  /// No description provided for @searchHint.
  ///
  /// In it, this message translates to:
  /// **'Cerca esercente, nota, categoria'**
  String get searchHint;

  /// No description provided for @noTransactionsTitle.
  ///
  /// In it, this message translates to:
  /// **'Nessun movimento'**
  String get noTransactionsTitle;

  /// No description provided for @noTransactionsMessage.
  ///
  /// In it, this message translates to:
  /// **'Le spese che aggiungi compariranno qui, divise per giorno.'**
  String get noTransactionsMessage;

  /// No description provided for @noResultsTitle.
  ///
  /// In it, this message translates to:
  /// **'Nessun risultato'**
  String get noResultsTitle;

  /// No description provided for @noResultsMessage.
  ///
  /// In it, this message translates to:
  /// **'Prova a cambiare la ricerca o i filtri.'**
  String get noResultsMessage;

  /// No description provided for @chooseCategory.
  ///
  /// In it, this message translates to:
  /// **'Scegli una categoria'**
  String get chooseCategory;

  /// No description provided for @expenseUpdated.
  ///
  /// In it, this message translates to:
  /// **'Spesa aggiornata'**
  String get expenseUpdated;

  /// No description provided for @expenseSaved.
  ///
  /// In it, this message translates to:
  /// **'Spesa salvata'**
  String get expenseSaved;

  /// No description provided for @expenseSavedIn.
  ///
  /// In it, this message translates to:
  /// **'Spesa salvata in {month}'**
  String expenseSavedIn(DateTime month);

  /// No description provided for @deleteExpenseTitle.
  ///
  /// In it, this message translates to:
  /// **'Eliminare la spesa?'**
  String get deleteExpenseTitle;

  /// No description provided for @deleteExpenseMessage.
  ///
  /// In it, this message translates to:
  /// **'La spesa e la foto dello scontrino verranno cancellate.'**
  String get deleteExpenseMessage;

  /// No description provided for @editExpense.
  ///
  /// In it, this message translates to:
  /// **'Modifica spesa'**
  String get editExpense;

  /// No description provided for @checkReceipt.
  ///
  /// In it, this message translates to:
  /// **'Controlla lo scontrino'**
  String get checkReceipt;

  /// No description provided for @newExpense.
  ///
  /// In it, this message translates to:
  /// **'Nuova spesa'**
  String get newExpense;

  /// No description provided for @amount.
  ///
  /// In it, this message translates to:
  /// **'Importo'**
  String get amount;

  /// No description provided for @enterAmount.
  ///
  /// In it, this message translates to:
  /// **'Inserisci un importo'**
  String get enterAmount;

  /// No description provided for @merchant.
  ///
  /// In it, this message translates to:
  /// **'Esercente'**
  String get merchant;

  /// No description provided for @merchantHint.
  ///
  /// In it, this message translates to:
  /// **'Es. Conad, Bar Roma'**
  String get merchantHint;

  /// No description provided for @category.
  ///
  /// In it, this message translates to:
  /// **'Categoria'**
  String get category;

  /// No description provided for @paidWith.
  ///
  /// In it, this message translates to:
  /// **'Pagato con'**
  String get paidWith;

  /// No description provided for @dateNotFound.
  ///
  /// In it, this message translates to:
  /// **'Data non trovata sullo scontrino'**
  String get dateNotFound;

  /// No description provided for @noteOptional.
  ///
  /// In it, this message translates to:
  /// **'Nota (facoltativa)'**
  String get noteOptional;

  /// No description provided for @suggestedLearned.
  ///
  /// In it, this message translates to:
  /// **'Suggerita: l\'hai già usata per questo esercente'**
  String get suggestedLearned;

  /// No description provided for @suggestedKeyword.
  ///
  /// In it, this message translates to:
  /// **'Suggerita dalla parola \"{word}\"'**
  String suggestedKeyword(String word);

  /// No description provided for @suggestedKeywordReceipt.
  ///
  /// In it, this message translates to:
  /// **'Suggerita dalla parola \"{word}\" sullo scontrino'**
  String suggestedKeywordReceipt(String word);

  /// No description provided for @receiptText.
  ///
  /// In it, this message translates to:
  /// **'Testo letto dallo scontrino'**
  String get receiptText;

  /// No description provided for @budgetNear.
  ///
  /// In it, this message translates to:
  /// **'{category}: hai usato il {percent}% del limite, restano {left}'**
  String budgetNear(String category, int percent, String left);

  /// No description provided for @budgetExhausted.
  ///
  /// In it, this message translates to:
  /// **'{category}: limite mensile esaurito'**
  String budgetExhausted(String category);

  /// No description provided for @budgetOver.
  ///
  /// In it, this message translates to:
  /// **'{category}: sei {over} oltre il limite'**
  String budgetOver(String category, String over);

  /// No description provided for @budgetReachedTitle.
  ///
  /// In it, this message translates to:
  /// **'Limite di {category} raggiunto'**
  String budgetReachedTitle(String category);

  /// No description provided for @budgetReachedExact.
  ///
  /// In it, this message translates to:
  /// **'Questo mese hai speso esattamente il limite di {limit}.'**
  String budgetReachedExact(String limit);

  /// No description provided for @budgetReachedOver.
  ///
  /// In it, this message translates to:
  /// **'Questo mese hai speso {spent} su un limite di {limit}: {over} in più.'**
  String budgetReachedOver(String spent, String limit, String over);

  /// No description provided for @gotIt.
  ///
  /// In it, this message translates to:
  /// **'Ho capito'**
  String get gotIt;

  /// No description provided for @summaryTitle.
  ///
  /// In it, this message translates to:
  /// **'Riepilogo'**
  String get summaryTitle;

  /// No description provided for @settings.
  ///
  /// In it, this message translates to:
  /// **'Impostazioni'**
  String get settings;

  /// No description provided for @noSpendingTitle.
  ///
  /// In it, this message translates to:
  /// **'Nessuna spesa questo mese'**
  String get noSpendingTitle;

  /// No description provided for @noSpendingMessage.
  ///
  /// In it, this message translates to:
  /// **'Tocca \"Aggiungi\" per fotografare uno scontrino o inserire una spesa a mano.'**
  String get noSpendingMessage;

  /// No description provided for @spentThisMonth.
  ///
  /// In it, this message translates to:
  /// **'Speso questo mese'**
  String get spentThisMonth;

  /// No description provided for @sameAsMonth.
  ///
  /// In it, this message translates to:
  /// **'Come {prep, select, ad{ad} other{a}} {month}'**
  String sameAsMonth(String prep, DateTime month);

  /// No description provided for @percentVsMonth.
  ///
  /// In it, this message translates to:
  /// **'{change}% rispetto {prep, select, ad{ad} other{a}} {month}'**
  String percentVsMonth(String change, String prep, DateTime month);

  /// No description provided for @amountVsMonth.
  ///
  /// In it, this message translates to:
  /// **'{change} rispetto {prep, select, ad{ad} other{a}} {month}'**
  String amountVsMonth(String change, String prep, DateTime month);

  /// No description provided for @nothingInMonth.
  ///
  /// In it, this message translates to:
  /// **'Niente {prep, select, ad{ad} other{a}} {month}'**
  String nothingInMonth(String prep, DateTime month);

  /// No description provided for @last6Months.
  ///
  /// In it, this message translates to:
  /// **'Ultimi 6 mesi'**
  String get last6Months;

  /// No description provided for @byCategory.
  ///
  /// In it, this message translates to:
  /// **'Per categoria'**
  String get byCategory;

  /// No description provided for @legendLimit.
  ///
  /// In it, this message translates to:
  /// **'limite'**
  String get legendLimit;

  /// No description provided for @remaining.
  ///
  /// In it, this message translates to:
  /// **'Restano {amount}'**
  String remaining(String amount);

  /// No description provided for @limitExhausted.
  ///
  /// In it, this message translates to:
  /// **'Limite esaurito'**
  String get limitExhausted;

  /// No description provided for @overBy.
  ///
  /// In it, this message translates to:
  /// **'Superato di {amount}'**
  String overBy(String amount);

  /// No description provided for @recentTransactions.
  ///
  /// In it, this message translates to:
  /// **'Ultimi movimenti'**
  String get recentTransactions;

  /// No description provided for @seeAll.
  ///
  /// In it, this message translates to:
  /// **'Vedi tutti'**
  String get seeAll;

  /// No description provided for @newCategory.
  ///
  /// In it, this message translates to:
  /// **'Nuova categoria'**
  String get newCategory;

  /// No description provided for @editCategory.
  ///
  /// In it, this message translates to:
  /// **'Modifica categoria'**
  String get editCategory;

  /// No description provided for @categoriesIntro.
  ///
  /// In it, this message translates to:
  /// **'Totali di {month}. Tocca una categoria per cambiarne nome, icona, colore o le parole che servono a riconoscerla sugli scontrini.'**
  String categoriesIntro(DateTime month);

  /// No description provided for @expenseCount.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =0{Nessuna spesa} =1{1 spesa} other{{count} spese}}'**
  String expenseCount(int count);

  /// No description provided for @monthlyLimitPerMonth.
  ///
  /// In it, this message translates to:
  /// **'Limite {amount} al mese'**
  String monthlyLimitPerMonth(String amount);

  /// No description provided for @limitInvalid.
  ///
  /// In it, this message translates to:
  /// **'Scrivi un importo, es. 100'**
  String get limitInvalid;

  /// No description provided for @onlyCategory.
  ///
  /// In it, this message translates to:
  /// **'È l\'unica categoria: creane un\'altra prima di eliminarla'**
  String get onlyCategory;

  /// No description provided for @deleteCategoryTitle.
  ///
  /// In it, this message translates to:
  /// **'Eliminare {name}?'**
  String deleteCategoryTitle(String name);

  /// No description provided for @categoryEmpty.
  ///
  /// In it, this message translates to:
  /// **'Non ci sono spese in questa categoria.'**
  String get categoryEmpty;

  /// No description provided for @moveExpensesTo.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{{name} ha 1 spesa. Spostala in:} other{{name} ha {count} spese. Spostale in:}}'**
  String moveExpensesTo(int count, String name);

  /// No description provided for @moveAndDelete.
  ///
  /// In it, this message translates to:
  /// **'Sposta ed elimina'**
  String get moveAndDelete;

  /// No description provided for @monthlyLimitLabel.
  ///
  /// In it, this message translates to:
  /// **'Limite mensile (facoltativo)'**
  String get monthlyLimitLabel;

  /// No description provided for @monthlyLimitHelper.
  ///
  /// In it, this message translates to:
  /// **'Ti avviso all\'80% e quando lo raggiungi. Lascia vuoto per nessun limite.'**
  String get monthlyLimitHelper;

  /// No description provided for @icon.
  ///
  /// In it, this message translates to:
  /// **'Icona'**
  String get icon;

  /// No description provided for @color.
  ///
  /// In it, this message translates to:
  /// **'Colore'**
  String get color;

  /// No description provided for @keywords.
  ///
  /// In it, this message translates to:
  /// **'Parole chiave'**
  String get keywords;

  /// No description provided for @keywordsHelper.
  ///
  /// In it, this message translates to:
  /// **'Parole che compaiono sugli scontrini, separate da virgola (es. farmacia, parafarmacia). Servono per gli esercenti mai visti: per quelli già usati l\'app ricorda la tua scelta.'**
  String get keywordsHelper;

  /// No description provided for @sectionAppearance.
  ///
  /// In it, this message translates to:
  /// **'Aspetto'**
  String get sectionAppearance;

  /// No description provided for @themeSystem.
  ///
  /// In it, this message translates to:
  /// **'Sistema'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In it, this message translates to:
  /// **'Chiaro'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In it, this message translates to:
  /// **'Scuro'**
  String get themeDark;

  /// No description provided for @appLanguage.
  ///
  /// In it, this message translates to:
  /// **'Lingua dell\'app'**
  String get appLanguage;

  /// No description provided for @languageSystem.
  ///
  /// In it, this message translates to:
  /// **'Sistema'**
  String get languageSystem;

  /// No description provided for @languageItalian.
  ///
  /// In it, this message translates to:
  /// **'Italiano'**
  String get languageItalian;

  /// No description provided for @languageEnglish.
  ///
  /// In it, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @accentGreen.
  ///
  /// In it, this message translates to:
  /// **'Verde'**
  String get accentGreen;

  /// No description provided for @accentBlue.
  ///
  /// In it, this message translates to:
  /// **'Blu'**
  String get accentBlue;

  /// No description provided for @accentPurple.
  ///
  /// In it, this message translates to:
  /// **'Viola'**
  String get accentPurple;

  /// No description provided for @accentPink.
  ///
  /// In it, this message translates to:
  /// **'Rosa'**
  String get accentPink;

  /// No description provided for @accentOrange.
  ///
  /// In it, this message translates to:
  /// **'Arancio'**
  String get accentOrange;

  /// No description provided for @accentGraphite.
  ///
  /// In it, this message translates to:
  /// **'Grafite'**
  String get accentGraphite;

  /// No description provided for @sectionSecurity.
  ///
  /// In it, this message translates to:
  /// **'Sicurezza'**
  String get sectionSecurity;

  /// No description provided for @changePassword.
  ///
  /// In it, this message translates to:
  /// **'Cambia password'**
  String get changePassword;

  /// No description provided for @currentPassword.
  ///
  /// In it, this message translates to:
  /// **'Password attuale'**
  String get currentPassword;

  /// No description provided for @newPassword.
  ///
  /// In it, this message translates to:
  /// **'Nuova password'**
  String get newPassword;

  /// No description provided for @repeatNewPassword.
  ///
  /// In it, this message translates to:
  /// **'Ripeti la nuova password'**
  String get repeatNewPassword;

  /// No description provided for @newPasswordTooShort.
  ///
  /// In it, this message translates to:
  /// **'La nuova password deve avere almeno 4 caratteri'**
  String get newPasswordTooShort;

  /// No description provided for @newPasswordsMismatch.
  ///
  /// In it, this message translates to:
  /// **'Le nuove password non coincidono'**
  String get newPasswordsMismatch;

  /// No description provided for @currentPasswordWrong.
  ///
  /// In it, this message translates to:
  /// **'La password attuale è sbagliata'**
  String get currentPasswordWrong;

  /// No description provided for @passwordChanged.
  ///
  /// In it, this message translates to:
  /// **'Password cambiata'**
  String get passwordChanged;

  /// No description provided for @biometricUnlock.
  ///
  /// In it, this message translates to:
  /// **'Sblocca con l\'impronta'**
  String get biometricUnlock;

  /// No description provided for @biometricKeepsPassword.
  ///
  /// In it, this message translates to:
  /// **'La password resta sempre valida'**
  String get biometricKeepsPassword;

  /// No description provided for @biometricNone.
  ///
  /// In it, this message translates to:
  /// **'Nessuna impronta registrata sul telefono'**
  String get biometricNone;

  /// No description provided for @sectionReceipts.
  ///
  /// In it, this message translates to:
  /// **'Scontrini'**
  String get sectionReceipts;

  /// No description provided for @receiptLanguage.
  ///
  /// In it, this message translates to:
  /// **'Lingua degli scontrini'**
  String get receiptLanguage;

  /// No description provided for @receiptLanguageHint.
  ///
  /// In it, this message translates to:
  /// **'Cambia le parole che il lettore cerca per trovare totale e data'**
  String get receiptLanguageHint;

  /// No description provided for @receiptLangItalian.
  ///
  /// In it, this message translates to:
  /// **'Italiano'**
  String get receiptLangItalian;

  /// No description provided for @receiptLangEnglish.
  ///
  /// In it, this message translates to:
  /// **'Inglese'**
  String get receiptLangEnglish;

  /// No description provided for @tryReader.
  ///
  /// In it, this message translates to:
  /// **'Prova il lettore'**
  String get tryReader;

  /// No description provided for @tryReaderHint.
  ///
  /// In it, this message translates to:
  /// **'Mostra il testo letto e i riquadri, senza salvare nulla'**
  String get tryReaderHint;

  /// No description provided for @sectionAccounts.
  ///
  /// In it, this message translates to:
  /// **'Conti'**
  String get sectionAccounts;

  /// No description provided for @addAccount.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi conto'**
  String get addAccount;

  /// No description provided for @newAccount.
  ///
  /// In it, this message translates to:
  /// **'Nuovo conto'**
  String get newAccount;

  /// No description provided for @editAccount.
  ///
  /// In it, this message translates to:
  /// **'Modifica conto'**
  String get editAccount;

  /// No description provided for @accountNameHint.
  ///
  /// In it, this message translates to:
  /// **'Es. Carta prepagata'**
  String get accountNameHint;

  /// No description provided for @archive.
  ///
  /// In it, this message translates to:
  /// **'Archivia'**
  String get archive;

  /// No description provided for @sectionData.
  ///
  /// In it, this message translates to:
  /// **'Dati'**
  String get sectionData;

  /// No description provided for @dataStaysOnPhone.
  ///
  /// In it, this message translates to:
  /// **'Tutto resta sul telefono'**
  String get dataStaysOnPhone;

  /// No description provided for @dataStaysOnPhoneHint.
  ///
  /// In it, this message translates to:
  /// **'Spese, foto e lettura degli scontrini non lasciano mai il dispositivo.'**
  String get dataStaysOnPhoneHint;

  /// No description provided for @exportData.
  ///
  /// In it, this message translates to:
  /// **'Esporta i dati'**
  String get exportData;

  /// No description provided for @exportDataHint.
  ///
  /// In it, this message translates to:
  /// **'Database e foto in un file .zip da salvare dove vuoi, es. su Drive. Il file non è cifrato.'**
  String get exportDataHint;

  /// No description provided for @exportShareTitle.
  ///
  /// In it, this message translates to:
  /// **'Esporta i dati di Receipt'**
  String get exportShareTitle;

  /// No description provided for @exportFailed.
  ///
  /// In it, this message translates to:
  /// **'Esportazione non riuscita: {error}'**
  String exportFailed(String error);

  /// No description provided for @importBackup.
  ///
  /// In it, this message translates to:
  /// **'Importa da backup'**
  String get importBackup;

  /// No description provided for @importBackupHint.
  ///
  /// In it, this message translates to:
  /// **'Ripristina da uno zip di \"Esporta i dati\". Sostituisce i dati attuali.'**
  String get importBackupHint;

  /// No description provided for @chooseBackup.
  ///
  /// In it, this message translates to:
  /// **'Scegli il backup (.zip)'**
  String get chooseBackup;

  /// No description provided for @restoreTitle.
  ///
  /// In it, this message translates to:
  /// **'Ripristinare il backup?'**
  String get restoreTitle;

  /// No description provided for @restoreSummary.
  ///
  /// In it, this message translates to:
  /// **'Backup: {expenses, plural, =1{1 spesa} other{{expenses} spese}}, {photos} foto.'**
  String restoreSummary(int expenses, int photos);

  /// No description provided for @restoreSummaryDated.
  ///
  /// In it, this message translates to:
  /// **'Backup del {date}: {expenses, plural, =1{1 spesa} other{{expenses} spese}}, {photos} foto.'**
  String restoreSummaryDated(DateTime date, int expenses, int photos);

  /// No description provided for @restoreReplaceWarning.
  ///
  /// In it, this message translates to:
  /// **'Tutti i dati attuali ({current, plural, =1{1 spesa} other{{current} spese}}, categorie, conti, limiti) verranno sostituiti. Se vuoi tenerli, esportali prima.'**
  String restoreReplaceWarning(int current);

  /// No description provided for @replace.
  ///
  /// In it, this message translates to:
  /// **'Sostituisci'**
  String get replace;

  /// No description provided for @restoreDone.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{Dati ripristinati: 1 spesa} other{Dati ripristinati: {count} spese}}'**
  String restoreDone(int count);

  /// No description provided for @restoreFailed.
  ///
  /// In it, this message translates to:
  /// **'Ripristino non riuscito: {error}'**
  String restoreFailed(String error);

  /// No description provided for @backupNotZip.
  ///
  /// In it, this message translates to:
  /// **'Il file non è uno zip valido.'**
  String get backupNotZip;

  /// No description provided for @backupNotReceipt.
  ///
  /// In it, this message translates to:
  /// **'Questo zip non è un backup di Receipt.'**
  String get backupNotReceipt;

  /// No description provided for @backupDamaged.
  ///
  /// In it, this message translates to:
  /// **'Il backup è danneggiato (manifest illeggibile).'**
  String get backupDamaged;

  /// No description provided for @backupNewer.
  ///
  /// In it, this message translates to:
  /// **'Il backup viene da una versione più nuova dell\'app: aggiorna Receipt e riprova.'**
  String get backupNewer;

  /// No description provided for @autoBackup.
  ///
  /// In it, this message translates to:
  /// **'Backup automatico cifrato'**
  String get autoBackup;

  /// No description provided for @comingSoon.
  ///
  /// In it, this message translates to:
  /// **'In arrivo'**
  String get comingSoon;

  /// No description provided for @loadDemo.
  ///
  /// In it, this message translates to:
  /// **'Carica dati di prova'**
  String get loadDemo;

  /// No description provided for @loadDemoHint.
  ///
  /// In it, this message translates to:
  /// **'Spese inventate a ottobre e settembre 2026, con alcuni limiti'**
  String get loadDemoHint;

  /// No description provided for @hidePassword.
  ///
  /// In it, this message translates to:
  /// **'Nascondi'**
  String get hidePassword;

  /// No description provided for @showPassword.
  ///
  /// In it, this message translates to:
  /// **'Mostra'**
  String get showPassword;

  /// No description provided for @passwordTooShort.
  ///
  /// In it, this message translates to:
  /// **'Almeno 4 caratteri'**
  String get passwordTooShort;

  /// No description provided for @passwordsMismatch.
  ///
  /// In it, this message translates to:
  /// **'Le password non coincidono'**
  String get passwordsMismatch;

  /// No description provided for @useBiometricTitle.
  ///
  /// In it, this message translates to:
  /// **'Vuoi usare l\'impronta?'**
  String get useBiometricTitle;

  /// No description provided for @useBiometricMessage.
  ///
  /// In it, this message translates to:
  /// **'Potrai aprire Receipt con l\'impronta invece di scrivere ogni volta la password. La password resta valida e la puoi sempre usare.'**
  String get useBiometricMessage;

  /// No description provided for @useBiometric.
  ///
  /// In it, this message translates to:
  /// **'Usa l\'impronta'**
  String get useBiometric;

  /// No description provided for @notNow.
  ///
  /// In it, this message translates to:
  /// **'Non ora'**
  String get notNow;

  /// No description provided for @setupTitle.
  ///
  /// In it, this message translates to:
  /// **'Proteggi le tue spese'**
  String get setupTitle;

  /// No description provided for @setupMessage.
  ///
  /// In it, this message translates to:
  /// **'Scegli una password per aprire Receipt. Non c\'è modo di recuperarla: tienila a mente o salvala nel tuo gestore di password.'**
  String get setupMessage;

  /// No description provided for @password.
  ///
  /// In it, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @repeatPassword.
  ///
  /// In it, this message translates to:
  /// **'Ripeti la password'**
  String get repeatPassword;

  /// No description provided for @continueLabel.
  ///
  /// In it, this message translates to:
  /// **'Continua'**
  String get continueLabel;

  /// No description provided for @wrongPassword.
  ///
  /// In it, this message translates to:
  /// **'Password sbagliata'**
  String get wrongPassword;

  /// No description provided for @lockedTitle.
  ///
  /// In it, this message translates to:
  /// **'Receipt è bloccata'**
  String get lockedTitle;

  /// No description provided for @lockedMessage.
  ///
  /// In it, this message translates to:
  /// **'Inserisci la password per continuare.'**
  String get lockedMessage;

  /// No description provided for @tooManyAttempts.
  ///
  /// In it, this message translates to:
  /// **'Troppi tentativi: riprova tra {seconds} s'**
  String tooManyAttempts(int seconds);

  /// No description provided for @unlock.
  ///
  /// In it, this message translates to:
  /// **'Sblocca'**
  String get unlock;

  /// No description provided for @biometricPromptUnlock.
  ///
  /// In it, this message translates to:
  /// **'Sblocca Receipt'**
  String get biometricPromptUnlock;

  /// No description provided for @biometricPromptConfirm.
  ///
  /// In it, this message translates to:
  /// **'Conferma l\'impronta per sbloccare Receipt'**
  String get biometricPromptConfirm;

  /// No description provided for @biometricUsePassword.
  ///
  /// In it, this message translates to:
  /// **'Usa la password'**
  String get biometricUsePassword;

  /// No description provided for @ocrTitle.
  ///
  /// In it, this message translates to:
  /// **'Lettore scontrini'**
  String get ocrTitle;

  /// No description provided for @copyText.
  ///
  /// In it, this message translates to:
  /// **'Copia testo'**
  String get copyText;

  /// No description provided for @textCopied.
  ///
  /// In it, this message translates to:
  /// **'Testo copiato'**
  String get textCopied;

  /// No description provided for @takePhoto.
  ///
  /// In it, this message translates to:
  /// **'Scatta'**
  String get takePhoto;

  /// No description provided for @gallery.
  ///
  /// In it, this message translates to:
  /// **'Galleria'**
  String get gallery;

  /// No description provided for @ocrIntro.
  ///
  /// In it, this message translates to:
  /// **'Il testo viene letto con RapidOCR direttamente sul telefono, senza connessione.'**
  String get ocrIntro;

  /// No description provided for @ocrLines.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 riga} other{{count} righe}}'**
  String ocrLines(int count);

  /// No description provided for @ocrBoxes.
  ///
  /// In it, this message translates to:
  /// **'Riquadri'**
  String get ocrBoxes;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
