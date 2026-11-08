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

  /// No description provided for @accentCustom.
  ///
  /// In it, this message translates to:
  /// **'Altro colore'**
  String get accentCustom;

  /// No description provided for @customColorTitle.
  ///
  /// In it, this message translates to:
  /// **'Scegli il colore'**
  String get customColorTitle;

  /// No description provided for @useColor.
  ///
  /// In it, this message translates to:
  /// **'Usa'**
  String get useColor;

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
  /// **'Spese, foto e lettura degli scontrini non lasciano mai il dispositivo. Spese e foto sono cifrate con la tua password.'**
  String get dataStaysOnPhoneHint;

  /// No description provided for @exportData.
  ///
  /// In it, this message translates to:
  /// **'Esporta i dati'**
  String get exportData;

  /// No description provided for @exportDataHint.
  ///
  /// In it, this message translates to:
  /// **'Database e foto in un file .zip da salvare dove vuoi, es. su Drive. Il file non è cifrato: serve la password per crearlo.'**
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
  /// **'Spese inventate a ottobre e settembre 2026 con qualche limite, e due isole piene'**
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
  /// **'Scegli una password per aprire Receipt: spese e foto vengono cifrate con questa. Non c\'è modo di recuperarla: tienila a mente o salvala nel tuo gestore di password.'**
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

  /// No description provided for @updateAvailable.
  ///
  /// In it, this message translates to:
  /// **'È disponibile Receipt {version} ({size})'**
  String updateAvailable(String version, String size);

  /// No description provided for @updateLater.
  ///
  /// In it, this message translates to:
  /// **'Non ora'**
  String get updateLater;

  /// No description provided for @updateNow.
  ///
  /// In it, this message translates to:
  /// **'Aggiorna'**
  String get updateNow;

  /// No description provided for @updateTitle.
  ///
  /// In it, this message translates to:
  /// **'Aggiornamento a {version}'**
  String updateTitle(String version);

  /// No description provided for @updateDownloading.
  ///
  /// In it, this message translates to:
  /// **'Scarico l\'aggiornamento…'**
  String get updateDownloading;

  /// No description provided for @updateProgress.
  ///
  /// In it, this message translates to:
  /// **'{done} di {total}'**
  String updateProgress(String done, String total);

  /// No description provided for @updatePermission.
  ///
  /// In it, this message translates to:
  /// **'Per installare l\'aggiornamento Android chiede di consentire a Receipt di installare app. Serve solo la prima volta.'**
  String get updatePermission;

  /// No description provided for @updateAllow.
  ///
  /// In it, this message translates to:
  /// **'Consenti'**
  String get updateAllow;

  /// No description provided for @updateInstalling.
  ///
  /// In it, this message translates to:
  /// **'Si apre l\'installer di Android: tocca «Aggiorna» per finire. Spese e foto restano dove sono.'**
  String get updateInstalling;

  /// No description provided for @updateErrorNetwork.
  ///
  /// In it, this message translates to:
  /// **'Download non riuscito. Controlla la connessione e riprova.'**
  String get updateErrorNetwork;

  /// No description provided for @updateErrorCorrupted.
  ///
  /// In it, this message translates to:
  /// **'Il file scaricato non corrisponde a quello pubblicato ed è stato scartato. Riprova.'**
  String get updateErrorCorrupted;

  /// No description provided for @retry.
  ///
  /// In it, this message translates to:
  /// **'Riprova'**
  String get retry;

  /// No description provided for @close.
  ///
  /// In it, this message translates to:
  /// **'Chiudi'**
  String get close;

  /// No description provided for @sectionUpdates.
  ///
  /// In it, this message translates to:
  /// **'Aggiornamenti'**
  String get sectionUpdates;

  /// No description provided for @updateCheckOnStart.
  ///
  /// In it, this message translates to:
  /// **'Controlla all\'avvio'**
  String get updateCheckOnStart;

  /// No description provided for @updateCheckOnStartHint.
  ///
  /// In it, this message translates to:
  /// **'Legge la versione disponibile dal sito di Receipt. Non viene inviato nessun tuo dato.'**
  String get updateCheckOnStartHint;

  /// No description provided for @updateCheckNow.
  ///
  /// In it, this message translates to:
  /// **'Controlla ora'**
  String get updateCheckNow;

  /// No description provided for @updateInstalledVersion.
  ///
  /// In it, this message translates to:
  /// **'Versione installata: {version}'**
  String updateInstalledVersion(String version);

  /// No description provided for @updateUpToDate.
  ///
  /// In it, this message translates to:
  /// **'Hai già l\'ultima versione'**
  String get updateUpToDate;

  /// No description provided for @updateCheckFailed.
  ///
  /// In it, this message translates to:
  /// **'Non riesco a controllare gli aggiornamenti: sei connesso?'**
  String get updateCheckFailed;

  /// No description provided for @scanRecovered.
  ///
  /// In it, this message translates to:
  /// **'Android aveva chiuso Receipt mentre scattavi: ecco la foto, la leggo ora.'**
  String get scanRecovered;

  /// No description provided for @chooseMonth.
  ///
  /// In it, this message translates to:
  /// **'Vai al mese'**
  String get chooseMonth;

  /// No description provided for @thisMonth.
  ///
  /// In it, this message translates to:
  /// **'Questo mese'**
  String get thisMonth;

  /// No description provided for @previousYear.
  ///
  /// In it, this message translates to:
  /// **'Anno precedente'**
  String get previousYear;

  /// No description provided for @nextYear.
  ///
  /// In it, this message translates to:
  /// **'Anno successivo'**
  String get nextYear;

  /// No description provided for @updateConsentTitle.
  ///
  /// In it, this message translates to:
  /// **'Aggiornamenti automatici'**
  String get updateConsentTitle;

  /// No description provided for @updateConsentMessage.
  ///
  /// In it, this message translates to:
  /// **'Receipt funziona tutta sul telefono e non raccoglie i tuoi dati. Vuoi che a ogni apertura controlli su internet se c\'è una nuova versione? Legge solo il numero di versione dal sito di Receipt. Puoi cambiare idea nelle Impostazioni.'**
  String get updateConsentMessage;

  /// No description provided for @updateConsentNo.
  ///
  /// In it, this message translates to:
  /// **'No, grazie'**
  String get updateConsentNo;

  /// No description provided for @updateConsentYes.
  ///
  /// In it, this message translates to:
  /// **'Sì, controlla'**
  String get updateConsentYes;

  /// No description provided for @dailyArt.
  ///
  /// In it, this message translates to:
  /// **'Quadro del giorno'**
  String get dailyArt;

  /// No description provided for @dailyArtHint.
  ///
  /// In it, this message translates to:
  /// **'Ogni giorno un dipinto del Metropolitan Museum of Art come sfondo, tra 600 di pubblico dominio. Scarica un\'immagine al giorno da Wikimedia Commons (circa 0,7 MB); nessun tuo dato viene inviato.'**
  String get dailyArtHint;

  /// No description provided for @dailyArtDownloading.
  ///
  /// In it, this message translates to:
  /// **'Scarico il quadro di oggi…'**
  String get dailyArtDownloading;

  /// No description provided for @dailyArtFailed.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a scaricare il quadro di oggi: riprovo quando torni nell\'app.'**
  String get dailyArtFailed;

  /// No description provided for @dailyArtToday.
  ///
  /// In it, this message translates to:
  /// **'Oggi: {title}, {artist}. Tocca la «i» in alto per saperne di più.'**
  String dailyArtToday(String title, String artist);

  /// No description provided for @paintingOfTheDay.
  ///
  /// In it, this message translates to:
  /// **'Il quadro di oggi'**
  String get paintingOfTheDay;

  /// No description provided for @paintingDate.
  ///
  /// In it, this message translates to:
  /// **'Data'**
  String get paintingDate;

  /// No description provided for @paintingMedium.
  ///
  /// In it, this message translates to:
  /// **'Tecnica'**
  String get paintingMedium;

  /// No description provided for @paintingDimensions.
  ///
  /// In it, this message translates to:
  /// **'Misure'**
  String get paintingDimensions;

  /// No description provided for @paintingCredit.
  ///
  /// In it, this message translates to:
  /// **'The Metropolitan Museum of Art, New York. {credit}'**
  String paintingCredit(String credit);

  /// No description provided for @paintingOpenMet.
  ///
  /// In it, this message translates to:
  /// **'Pagina del Met'**
  String get paintingOpenMet;

  /// No description provided for @paintingFromWikipedia.
  ///
  /// In it, this message translates to:
  /// **'Da Wikipedia, voce «{title}» (CC BY-SA 4.0)'**
  String paintingFromWikipedia(String title);

  /// No description provided for @paintingFromWikidata.
  ///
  /// In it, this message translates to:
  /// **'Da Wikidata (CC0)'**
  String get paintingFromWikidata;

  /// No description provided for @paintingSources.
  ///
  /// In it, this message translates to:
  /// **'Dati dell\'opera: Open Access del Met e Wikidata (CC0). Immagine: Wikimedia Commons ({license}).'**
  String paintingSources(String license);

  /// No description provided for @paintingOpenWikipedia.
  ///
  /// In it, this message translates to:
  /// **'Wikipedia'**
  String get paintingOpenWikipedia;

  /// No description provided for @paintingOpenCommons.
  ///
  /// In it, this message translates to:
  /// **'Immagine su Commons'**
  String get paintingOpenCommons;

  /// No description provided for @dailyArtConsentMessage.
  ///
  /// In it, this message translates to:
  /// **'Vuoi come sfondo un dipinto del Metropolitan Museum of Art, diverso ogni giorno? Receipt scarica un\'immagine al giorno da Wikimedia Commons (circa 0,7 MB) e non invia nessun tuo dato. Puoi cambiare idea nelle Impostazioni.'**
  String get dailyArtConsentMessage;

  /// No description provided for @dailyArtConsentInternet.
  ///
  /// In it, this message translates to:
  /// **'Hai scelto di non far usare internet a Receipt per gli aggiornamenti. Il quadro del giorno ha bisogno di internet: attivandolo, l\'app si collegherà solo per scaricare l\'immagine di oggi.'**
  String get dailyArtConsentInternet;

  /// No description provided for @dailyArtConsentYes.
  ///
  /// In it, this message translates to:
  /// **'Sì, attiva'**
  String get dailyArtConsentYes;

  /// No description provided for @dailyArtVisibility.
  ///
  /// In it, this message translates to:
  /// **'Visibilità del quadro: {percent}%'**
  String dailyArtVisibility(String percent);

  /// No description provided for @backupNotZipNamed.
  ///
  /// In it, this message translates to:
  /// **'«{file}» non è uno zip valido.'**
  String backupNotZipNamed(String file);

  /// No description provided for @backupNotReceiptDetail.
  ///
  /// In it, this message translates to:
  /// **'«{file}» non è un backup di Receipt: non trovo {missing}. Nello zip c\'è: {found}.'**
  String backupNotReceiptDetail(String file, String missing, String found);

  /// No description provided for @lockedUpgradeMessage.
  ///
  /// In it, this message translates to:
  /// **'Questa volta serve la password, non l\'impronta: da questa versione Receipt la usa per cifrare spese e foto sul telefono.'**
  String get lockedUpgradeMessage;

  /// No description provided for @biometricChangedMessage.
  ///
  /// In it, this message translates to:
  /// **'Le impronte del telefono sono cambiate: entra con la password, poi potrai riattivare l\'impronta.'**
  String get biometricChangedMessage;

  /// No description provided for @biometricConfirmTitle.
  ///
  /// In it, this message translates to:
  /// **'Continuare con l\'impronta?'**
  String get biometricConfirmTitle;

  /// No description provided for @biometricConfirmMessage.
  ///
  /// In it, this message translates to:
  /// **'Spese e foto sono cifrate con la tua password. Per aprirle anche con l\'impronta, confermala una volta.'**
  String get biometricConfirmMessage;

  /// No description provided for @exportPasswordTitle.
  ///
  /// In it, this message translates to:
  /// **'Conferma con la password'**
  String get exportPasswordTitle;

  /// No description provided for @exportPasswordMessage.
  ///
  /// In it, this message translates to:
  /// **'Il file esportato non è cifrato: chi lo apre vede spese e foto. Per crearlo serve la password.'**
  String get exportPasswordMessage;

  /// No description provided for @exportAction.
  ///
  /// In it, this message translates to:
  /// **'Esporta'**
  String get exportAction;

  /// No description provided for @updateWhatsNew.
  ///
  /// In it, this message translates to:
  /// **'Cosa c\'è di nuovo'**
  String get updateWhatsNew;

  /// No description provided for @updateDownloadSize.
  ///
  /// In it, this message translates to:
  /// **'Download di {size}'**
  String updateDownloadSize(String size);

  /// No description provided for @islandTooltip.
  ///
  /// In it, this message translates to:
  /// **'La tua isola'**
  String get islandTooltip;

  /// No description provided for @islandTitle.
  ///
  /// In it, this message translates to:
  /// **'Isola {year}'**
  String islandTitle(String year);

  /// No description provided for @islandHowTitle.
  ///
  /// In it, this message translates to:
  /// **'Come funziona'**
  String get islandHowTitle;

  /// No description provided for @islandHowBody.
  ///
  /// In it, this message translates to:
  /// **'Ogni mese in cui resti nei limiti puoi piantare qualcosa sull\'isola: scegli tu cosa e dove.\n\nConta il totale delle categorie che hanno un limite: se una sfora ma le altre compensano, il mese vale lo stesso. Serve almeno un limite.\n\nIl mese deve essere registrato con la regolarità di sempre: non registrare non è risparmiare. Conta la data della spesa, non quando la inserisci.\n\nValgono i limiti del giorno 5: se li cambi dopo, per l\'isola contano dal mese successivo.\n\nOgni anno è un\'isola nuova. Se a fine anno hai piantato più di metà dei posti, al centro spunta una sorpresa.'**
  String get islandHowBody;

  /// No description provided for @islandPreviousYear.
  ///
  /// In it, this message translates to:
  /// **'Isola dell\'anno prima'**
  String get islandPreviousYear;

  /// No description provided for @islandNextYear.
  ///
  /// In it, this message translates to:
  /// **'Isola dell\'anno dopo'**
  String get islandNextYear;

  /// No description provided for @islandPendingCount.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{Hai una pianta da mettere} other{Hai {count} piante da mettere}}'**
  String islandPendingCount(int count);

  /// No description provided for @islandChoosePlant.
  ///
  /// In it, this message translates to:
  /// **'Scegli la pianta di {month}'**
  String islandChoosePlant(String month);

  /// No description provided for @islandGiftNote.
  ///
  /// In it, this message translates to:
  /// **'La pianta di {month} è un regalo, per vedere come funziona.'**
  String islandGiftNote(String month);

  /// No description provided for @islandTapSpot.
  ///
  /// In it, this message translates to:
  /// **'Tocca un posto libero sull\'isola'**
  String get islandTapSpot;

  /// No description provided for @islandPlaced.
  ///
  /// In it, this message translates to:
  /// **'{plant} è sull\'isola'**
  String islandPlaced(String plant);

  /// No description provided for @islandPlantFailed.
  ///
  /// In it, this message translates to:
  /// **'Non si può piantare: qualcosa è cambiato, riprova.'**
  String get islandPlantFailed;

  /// No description provided for @islandPickerTitle.
  ///
  /// In it, this message translates to:
  /// **'Cosa vuoi piantare?'**
  String get islandPickerTitle;

  /// No description provided for @islandGroupTree.
  ///
  /// In it, this message translates to:
  /// **'Alberi'**
  String get islandGroupTree;

  /// No description provided for @islandGroupFruitTree.
  ///
  /// In it, this message translates to:
  /// **'Alberi da frutto'**
  String get islandGroupFruitTree;

  /// No description provided for @islandGroupConifer.
  ///
  /// In it, this message translates to:
  /// **'Conifere'**
  String get islandGroupConifer;

  /// No description provided for @islandGroupPalm.
  ///
  /// In it, this message translates to:
  /// **'Palme'**
  String get islandGroupPalm;

  /// No description provided for @islandGroupShrub.
  ///
  /// In it, this message translates to:
  /// **'Arbusti'**
  String get islandGroupShrub;

  /// No description provided for @islandGroupFlower.
  ///
  /// In it, this message translates to:
  /// **'Fiori'**
  String get islandGroupFlower;

  /// No description provided for @islandGroupSucculent.
  ///
  /// In it, this message translates to:
  /// **'Piante grasse'**
  String get islandGroupSucculent;

  /// No description provided for @islandBlooms.
  ///
  /// In it, this message translates to:
  /// **'Fiorisce {range}'**
  String islandBlooms(String range);

  /// No description provided for @islandFruits.
  ///
  /// In it, this message translates to:
  /// **'Frutti {range}'**
  String islandFruits(String range);

  /// No description provided for @islandFruitsAllYear.
  ///
  /// In it, this message translates to:
  /// **'Frutti tutto l\'anno'**
  String get islandFruitsAllYear;

  /// No description provided for @islandEvergreen.
  ///
  /// In it, this message translates to:
  /// **'Sempreverde'**
  String get islandEvergreen;

  /// No description provided for @islandDeciduous.
  ///
  /// In it, this message translates to:
  /// **'Spoglio d\'inverno'**
  String get islandDeciduous;

  /// No description provided for @islandGiftLabel.
  ///
  /// In it, this message translates to:
  /// **'regalo'**
  String get islandGiftLabel;

  /// No description provided for @islandRewardProgress.
  ///
  /// In it, this message translates to:
  /// **'Piante: {planted} su {needed}. Con {needed} a fine anno, al centro spunta una sorpresa.'**
  String islandRewardProgress(int planted, int needed);

  /// No description provided for @islandRewardReady.
  ///
  /// In it, this message translates to:
  /// **'Ci sei: a fine anno al centro spunta una sorpresa.'**
  String get islandRewardReady;

  /// No description provided for @islandRewardEarned.
  ///
  /// In it, this message translates to:
  /// **'Premio dell\'anno: {name}'**
  String islandRewardEarned(String name);

  /// No description provided for @islandRewardMissed.
  ///
  /// In it, this message translates to:
  /// **'Quest\'anno niente premio: servivano {needed} piante.'**
  String islandRewardMissed(int needed);

  /// No description provided for @islandComplete.
  ///
  /// In it, this message translates to:
  /// **'Isola completa!'**
  String get islandComplete;

  /// No description provided for @islandCurrentMonth.
  ///
  /// In it, this message translates to:
  /// **'{month} finora: {spent} su {limit}'**
  String islandCurrentMonth(String month, String spent, String limit);

  /// No description provided for @islandCurrentOver.
  ///
  /// In it, this message translates to:
  /// **'Sei oltre i limiti: questo mese niente pianta.'**
  String get islandCurrentOver;

  /// No description provided for @islandCurrentGap.
  ///
  /// In it, this message translates to:
  /// **'{days} giorni di fila senza spese: per il mese il massimo è {max}.'**
  String islandCurrentGap(int days, int max);

  /// No description provided for @islandCurrentOk.
  ///
  /// In it, this message translates to:
  /// **'Registrazioni regolari'**
  String get islandCurrentOk;

  /// No description provided for @islandNoLimits.
  ///
  /// In it, this message translates to:
  /// **'Per piantare serve almeno un limite mensile: impostalo in Categorie.'**
  String get islandNoLimits;

  /// No description provided for @islandNoLimitsThisMonth.
  ///
  /// In it, this message translates to:
  /// **'Per l\'isola questo mese non ci sono limiti: quelli impostati dopo il 5 valgono da {month}.'**
  String islandNoLimitsThisMonth(String month);

  /// No description provided for @islandMonthPending.
  ///
  /// In it, this message translates to:
  /// **'Da piantare'**
  String get islandMonthPending;

  /// No description provided for @islandMonthOver.
  ///
  /// In it, this message translates to:
  /// **'Oltre i limiti: {spent} su {limit}'**
  String islandMonthOver(String spent, String limit);

  /// No description provided for @islandMonthNoLimits.
  ///
  /// In it, this message translates to:
  /// **'Nessun limite'**
  String get islandMonthNoLimits;

  /// No description provided for @islandMonthNoRecords.
  ///
  /// In it, this message translates to:
  /// **'Nessuna spesa registrata'**
  String get islandMonthNoRecords;

  /// No description provided for @islandMonthGap.
  ///
  /// In it, this message translates to:
  /// **'{days} giorni di fila senza spese'**
  String islandMonthGap(int days);

  /// No description provided for @islandMonthFew.
  ///
  /// In it, this message translates to:
  /// **'Poche spese registrate: {records}, ne servivano {minimum}'**
  String islandMonthFew(int records, int minimum);

  /// No description provided for @islandMonthInProgress.
  ///
  /// In it, this message translates to:
  /// **'In corso'**
  String get islandMonthInProgress;

  /// No description provided for @islandLimitChangeTitle.
  ///
  /// In it, this message translates to:
  /// **'Per l\'isola vale da {month}'**
  String islandLimitChangeTitle(String month);

  /// No description provided for @islandLimitChangeBody.
  ///
  /// In it, this message translates to:
  /// **'I limiti cambiati dopo il 5 contano per l\'isola dal mese successivo: per {month} restano quelli di inizio mese. Gli avvisi invece usano subito il nuovo limite.'**
  String islandLimitChangeBody(String month);

  /// No description provided for @plantOak.
  ///
  /// In it, this message translates to:
  /// **'Quercia'**
  String get plantOak;

  /// No description provided for @plantOlive.
  ///
  /// In it, this message translates to:
  /// **'Ulivo'**
  String get plantOlive;

  /// No description provided for @plantMaple.
  ///
  /// In it, this message translates to:
  /// **'Acero'**
  String get plantMaple;

  /// No description provided for @plantBirch.
  ///
  /// In it, this message translates to:
  /// **'Betulla'**
  String get plantBirch;

  /// No description provided for @plantWillow.
  ///
  /// In it, this message translates to:
  /// **'Salice piangente'**
  String get plantWillow;

  /// No description provided for @plantStonePine.
  ///
  /// In it, this message translates to:
  /// **'Pino domestico'**
  String get plantStonePine;

  /// No description provided for @plantLemon.
  ///
  /// In it, this message translates to:
  /// **'Limone'**
  String get plantLemon;

  /// No description provided for @plantOrange.
  ///
  /// In it, this message translates to:
  /// **'Arancio'**
  String get plantOrange;

  /// No description provided for @plantApple.
  ///
  /// In it, this message translates to:
  /// **'Melo'**
  String get plantApple;

  /// No description provided for @plantCherry.
  ///
  /// In it, this message translates to:
  /// **'Ciliegio'**
  String get plantCherry;

  /// No description provided for @plantAlmond.
  ///
  /// In it, this message translates to:
  /// **'Mandorlo'**
  String get plantAlmond;

  /// No description provided for @plantFig.
  ///
  /// In it, this message translates to:
  /// **'Fico'**
  String get plantFig;

  /// No description provided for @plantFir.
  ///
  /// In it, this message translates to:
  /// **'Abete'**
  String get plantFir;

  /// No description provided for @plantCypress.
  ///
  /// In it, this message translates to:
  /// **'Cipresso'**
  String get plantCypress;

  /// No description provided for @plantDatePalm.
  ///
  /// In it, this message translates to:
  /// **'Palma da dattero'**
  String get plantDatePalm;

  /// No description provided for @plantFanPalm.
  ///
  /// In it, this message translates to:
  /// **'Palma nana'**
  String get plantFanPalm;

  /// No description provided for @plantLavender.
  ///
  /// In it, this message translates to:
  /// **'Lavanda'**
  String get plantLavender;

  /// No description provided for @plantRosemary.
  ///
  /// In it, this message translates to:
  /// **'Rosmarino'**
  String get plantRosemary;

  /// No description provided for @plantOleander.
  ///
  /// In it, this message translates to:
  /// **'Oleandro'**
  String get plantOleander;

  /// No description provided for @plantHydrangea.
  ///
  /// In it, this message translates to:
  /// **'Ortensia'**
  String get plantHydrangea;

  /// No description provided for @plantBougainvillea.
  ///
  /// In it, this message translates to:
  /// **'Bouganville'**
  String get plantBougainvillea;

  /// No description provided for @plantSunflower.
  ///
  /// In it, this message translates to:
  /// **'Girasole'**
  String get plantSunflower;

  /// No description provided for @plantPoppy.
  ///
  /// In it, this message translates to:
  /// **'Papavero'**
  String get plantPoppy;

  /// No description provided for @plantDaisy.
  ///
  /// In it, this message translates to:
  /// **'Margherita'**
  String get plantDaisy;

  /// No description provided for @plantTulip.
  ///
  /// In it, this message translates to:
  /// **'Tulipano'**
  String get plantTulip;

  /// No description provided for @plantRose.
  ///
  /// In it, this message translates to:
  /// **'Rosa'**
  String get plantRose;

  /// No description provided for @plantIris.
  ///
  /// In it, this message translates to:
  /// **'Iris'**
  String get plantIris;

  /// No description provided for @plantJasmine.
  ///
  /// In it, this message translates to:
  /// **'Gelsomino'**
  String get plantJasmine;

  /// No description provided for @plantPricklyPear.
  ///
  /// In it, this message translates to:
  /// **'Fico d\'India'**
  String get plantPricklyPear;

  /// No description provided for @plantAgave.
  ///
  /// In it, this message translates to:
  /// **'Agave'**
  String get plantAgave;

  /// No description provided for @plantAloe.
  ///
  /// In it, this message translates to:
  /// **'Aloe'**
  String get plantAloe;

  /// No description provided for @plantCactus.
  ///
  /// In it, this message translates to:
  /// **'Cactus'**
  String get plantCactus;

  /// No description provided for @centerpieceLighthouse.
  ///
  /// In it, this message translates to:
  /// **'un faro'**
  String get centerpieceLighthouse;

  /// No description provided for @centerpieceFountain.
  ///
  /// In it, this message translates to:
  /// **'una fontana'**
  String get centerpieceFountain;

  /// No description provided for @centerpieceTemple.
  ///
  /// In it, this message translates to:
  /// **'un tempietto'**
  String get centerpieceTemple;

  /// No description provided for @centerpieceStatue.
  ///
  /// In it, this message translates to:
  /// **'una statua'**
  String get centerpieceStatue;

  /// No description provided for @centerpieceObelisk.
  ///
  /// In it, this message translates to:
  /// **'un obelisco'**
  String get centerpieceObelisk;
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
