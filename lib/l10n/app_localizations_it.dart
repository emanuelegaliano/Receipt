// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get cancel => 'Annulla';

  @override
  String get undo => 'Annulla';

  @override
  String get save => 'Salva';

  @override
  String get delete => 'Elimina';

  @override
  String get add => 'Aggiungi';

  @override
  String get name => 'Nome';

  @override
  String get today => 'Oggi';

  @override
  String get yesterday => 'Ieri';

  @override
  String get catGroceries => 'Spesa';

  @override
  String get catRestaurants => 'Ristoranti e bar';

  @override
  String get catTransport => 'Trasporti';

  @override
  String get catHome => 'Casa e bollette';

  @override
  String get catHealth => 'Salute';

  @override
  String get catShopping => 'Shopping';

  @override
  String get catLeisure => 'Svago';

  @override
  String get catOther => 'Altro';

  @override
  String get accountCard => 'Carta';

  @override
  String get accountCash => 'Contanti';

  @override
  String get accountOther => 'Altro';

  @override
  String get navSummary => 'Riepilogo';

  @override
  String get navTransactions => 'Movimenti';

  @override
  String get navCategories => 'Categorie';

  @override
  String get addScanTitle => 'Fotografa uno scontrino';

  @override
  String get addScanSubtitle =>
      'Importo, data ed esercente letti in automatico';

  @override
  String get addGalleryTitle => 'Scegli dalla galleria';

  @override
  String get addGallerySubtitle => 'Usa una foto di uno scontrino già scattata';

  @override
  String get addManualTitle => 'Inserisci a mano';

  @override
  String get addManualSubtitle => 'Per spese senza scontrino, es. in contanti';

  @override
  String get previousMonth => 'Mese precedente';

  @override
  String get nextMonth => 'Mese successivo';

  @override
  String get receiptTitle => 'Scontrino';

  @override
  String get scanPreparing => 'Preparo il lettore…';

  @override
  String get scanReading => 'Leggo lo scontrino…';

  @override
  String get scanOffline => 'Tutto avviene sul telefono, senza connessione.';

  @override
  String get scanFailed => 'Non sono riuscito a leggere lo scontrino';

  @override
  String get scanWarnNoText =>
      'Non ho trovato testo: prova con una foto più nitida e dritta.';

  @override
  String get scanWarnNoTotal => 'Totale non trovato: inseriscilo a mano.';

  @override
  String get scanWarnNoMerchant => 'Esercente non trovato.';

  @override
  String expenseDeleted(String amount) {
    return 'Spesa eliminata: $amount';
  }

  @override
  String get searchHint => 'Cerca esercente, nota, categoria';

  @override
  String get noTransactionsTitle => 'Nessun movimento';

  @override
  String get noTransactionsMessage =>
      'Le spese che aggiungi compariranno qui, divise per giorno.';

  @override
  String get noResultsTitle => 'Nessun risultato';

  @override
  String get noResultsMessage => 'Prova a cambiare la ricerca o i filtri.';

  @override
  String get chooseCategory => 'Scegli una categoria';

  @override
  String get expenseUpdated => 'Spesa aggiornata';

  @override
  String get expenseSaved => 'Spesa salvata';

  @override
  String expenseSavedIn(DateTime month) {
    final intl.DateFormat monthDateFormat = intl.DateFormat.yMMMM(localeName);
    final String monthString = monthDateFormat.format(month);

    return 'Spesa salvata in $monthString';
  }

  @override
  String get deleteExpenseTitle => 'Eliminare la spesa?';

  @override
  String get deleteExpenseMessage =>
      'La spesa e la foto dello scontrino verranno cancellate.';

  @override
  String get editExpense => 'Modifica spesa';

  @override
  String get checkReceipt => 'Controlla lo scontrino';

  @override
  String get newExpense => 'Nuova spesa';

  @override
  String get amount => 'Importo';

  @override
  String get enterAmount => 'Inserisci un importo';

  @override
  String get merchant => 'Esercente';

  @override
  String get merchantHint => 'Es. Conad, Bar Roma';

  @override
  String get category => 'Categoria';

  @override
  String get paidWith => 'Pagato con';

  @override
  String get dateNotFound => 'Data non trovata sullo scontrino';

  @override
  String get noteOptional => 'Nota (facoltativa)';

  @override
  String get suggestedLearned =>
      'Suggerita: l\'hai già usata per questo esercente';

  @override
  String suggestedKeyword(String word) {
    return 'Suggerita dalla parola \"$word\"';
  }

  @override
  String suggestedKeywordReceipt(String word) {
    return 'Suggerita dalla parola \"$word\" sullo scontrino';
  }

  @override
  String get receiptText => 'Testo letto dallo scontrino';

  @override
  String budgetNear(String category, int percent, String left) {
    return '$category: hai usato il $percent% del limite, restano $left';
  }

  @override
  String budgetExhausted(String category) {
    return '$category: limite mensile esaurito';
  }

  @override
  String budgetOver(String category, String over) {
    return '$category: sei $over oltre il limite';
  }

  @override
  String budgetReachedTitle(String category) {
    return 'Limite di $category raggiunto';
  }

  @override
  String budgetReachedExact(String limit) {
    return 'Questo mese hai speso esattamente il limite di $limit.';
  }

  @override
  String budgetReachedOver(String spent, String limit, String over) {
    return 'Questo mese hai speso $spent su un limite di $limit: $over in più.';
  }

  @override
  String get gotIt => 'Ho capito';

  @override
  String get summaryTitle => 'Riepilogo';

  @override
  String get settings => 'Impostazioni';

  @override
  String get noSpendingTitle => 'Nessuna spesa questo mese';

  @override
  String get noSpendingMessage =>
      'Tocca \"Aggiungi\" per fotografare uno scontrino o inserire una spesa a mano.';

  @override
  String get spentThisMonth => 'Speso questo mese';

  @override
  String sameAsMonth(String prep, DateTime month) {
    final intl.DateFormat monthDateFormat = intl.DateFormat.MMMM(localeName);
    final String monthString = monthDateFormat.format(month);

    String _temp0 = intl.Intl.selectLogic(prep, {'ad': 'ad', 'other': 'a'});
    return 'Come $_temp0 $monthString';
  }

  @override
  String percentVsMonth(String change, String prep, DateTime month) {
    final intl.DateFormat monthDateFormat = intl.DateFormat.MMMM(localeName);
    final String monthString = monthDateFormat.format(month);

    String _temp0 = intl.Intl.selectLogic(prep, {'ad': 'ad', 'other': 'a'});
    return '$change% rispetto $_temp0 $monthString';
  }

  @override
  String amountVsMonth(String change, String prep, DateTime month) {
    final intl.DateFormat monthDateFormat = intl.DateFormat.MMMM(localeName);
    final String monthString = monthDateFormat.format(month);

    String _temp0 = intl.Intl.selectLogic(prep, {'ad': 'ad', 'other': 'a'});
    return '$change rispetto $_temp0 $monthString';
  }

  @override
  String nothingInMonth(String prep, DateTime month) {
    final intl.DateFormat monthDateFormat = intl.DateFormat.MMMM(localeName);
    final String monthString = monthDateFormat.format(month);

    String _temp0 = intl.Intl.selectLogic(prep, {'ad': 'ad', 'other': 'a'});
    return 'Niente $_temp0 $monthString';
  }

  @override
  String get last6Months => 'Ultimi 6 mesi';

  @override
  String get byCategory => 'Per categoria';

  @override
  String get legendLimit => 'limite';

  @override
  String remaining(String amount) {
    return 'Restano $amount';
  }

  @override
  String get limitExhausted => 'Limite esaurito';

  @override
  String overBy(String amount) {
    return 'Superato di $amount';
  }

  @override
  String get recentTransactions => 'Ultimi movimenti';

  @override
  String get seeAll => 'Vedi tutti';

  @override
  String get newCategory => 'Nuova categoria';

  @override
  String get editCategory => 'Modifica categoria';

  @override
  String categoriesIntro(DateTime month) {
    final intl.DateFormat monthDateFormat = intl.DateFormat.yMMMM(localeName);
    final String monthString = monthDateFormat.format(month);

    return 'Totali di $monthString. Tocca una categoria per cambiarne nome, icona, colore o le parole che servono a riconoscerla sugli scontrini.';
  }

  @override
  String expenseCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count spese',
      one: '1 spesa',
      zero: 'Nessuna spesa',
    );
    return '$_temp0';
  }

  @override
  String monthlyLimitPerMonth(String amount) {
    return 'Limite $amount al mese';
  }

  @override
  String get limitInvalid => 'Scrivi un importo, es. 100';

  @override
  String get onlyCategory =>
      'È l\'unica categoria: creane un\'altra prima di eliminarla';

  @override
  String deleteCategoryTitle(String name) {
    return 'Eliminare $name?';
  }

  @override
  String get categoryEmpty => 'Non ci sono spese in questa categoria.';

  @override
  String moveExpensesTo(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name ha $count spese. Spostale in:',
      one: '$name ha 1 spesa. Spostala in:',
    );
    return '$_temp0';
  }

  @override
  String get moveAndDelete => 'Sposta ed elimina';

  @override
  String get monthlyLimitLabel => 'Limite mensile (facoltativo)';

  @override
  String get monthlyLimitHelper =>
      'Ti avviso all\'80% e quando lo raggiungi. Lascia vuoto per nessun limite.';

  @override
  String get icon => 'Icona';

  @override
  String get color => 'Colore';

  @override
  String get keywords => 'Parole chiave';

  @override
  String get keywordsHelper =>
      'Parole che compaiono sugli scontrini, separate da virgola (es. farmacia, parafarmacia). Servono per gli esercenti mai visti: per quelli già usati l\'app ricorda la tua scelta.';

  @override
  String get sectionAppearance => 'Aspetto';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Chiaro';

  @override
  String get themeDark => 'Scuro';

  @override
  String get appLanguage => 'Lingua dell\'app';

  @override
  String get languageSystem => 'Sistema';

  @override
  String get languageItalian => 'Italiano';

  @override
  String get languageEnglish => 'English';

  @override
  String get accentGreen => 'Verde';

  @override
  String get accentBlue => 'Blu';

  @override
  String get accentPurple => 'Viola';

  @override
  String get accentPink => 'Rosa';

  @override
  String get accentOrange => 'Arancio';

  @override
  String get accentGraphite => 'Grafite';

  @override
  String get sectionSecurity => 'Sicurezza';

  @override
  String get changePassword => 'Cambia password';

  @override
  String get currentPassword => 'Password attuale';

  @override
  String get newPassword => 'Nuova password';

  @override
  String get repeatNewPassword => 'Ripeti la nuova password';

  @override
  String get newPasswordTooShort =>
      'La nuova password deve avere almeno 4 caratteri';

  @override
  String get newPasswordsMismatch => 'Le nuove password non coincidono';

  @override
  String get currentPasswordWrong => 'La password attuale è sbagliata';

  @override
  String get passwordChanged => 'Password cambiata';

  @override
  String get biometricUnlock => 'Sblocca con l\'impronta';

  @override
  String get biometricKeepsPassword => 'La password resta sempre valida';

  @override
  String get biometricNone => 'Nessuna impronta registrata sul telefono';

  @override
  String get sectionReceipts => 'Scontrini';

  @override
  String get receiptLanguage => 'Lingua degli scontrini';

  @override
  String get receiptLanguageHint =>
      'Cambia le parole che il lettore cerca per trovare totale e data';

  @override
  String get receiptLangItalian => 'Italiano';

  @override
  String get receiptLangEnglish => 'Inglese';

  @override
  String get tryReader => 'Prova il lettore';

  @override
  String get tryReaderHint =>
      'Mostra il testo letto e i riquadri, senza salvare nulla';

  @override
  String get sectionAccounts => 'Conti';

  @override
  String get addAccount => 'Aggiungi conto';

  @override
  String get newAccount => 'Nuovo conto';

  @override
  String get editAccount => 'Modifica conto';

  @override
  String get accountNameHint => 'Es. Carta prepagata';

  @override
  String get archive => 'Archivia';

  @override
  String get sectionData => 'Dati';

  @override
  String get dataStaysOnPhone => 'Tutto resta sul telefono';

  @override
  String get dataStaysOnPhoneHint =>
      'Spese, foto e lettura degli scontrini non lasciano mai il dispositivo.';

  @override
  String get exportData => 'Esporta i dati';

  @override
  String get exportDataHint =>
      'Database e foto in un file .zip da salvare dove vuoi, es. su Drive. Il file non è cifrato.';

  @override
  String get exportShareTitle => 'Esporta i dati di Receipt';

  @override
  String exportFailed(String error) {
    return 'Esportazione non riuscita: $error';
  }

  @override
  String get importBackup => 'Importa da backup';

  @override
  String get importBackupHint =>
      'Ripristina da uno zip di \"Esporta i dati\". Sostituisce i dati attuali.';

  @override
  String get chooseBackup => 'Scegli il backup (.zip)';

  @override
  String get restoreTitle => 'Ripristinare il backup?';

  @override
  String restoreSummary(int expenses, int photos) {
    String _temp0 = intl.Intl.pluralLogic(
      expenses,
      locale: localeName,
      other: '$expenses spese',
      one: '1 spesa',
    );
    return 'Backup: $_temp0, $photos foto.';
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
      other: '$expenses spese',
      one: '1 spesa',
    );
    return 'Backup del $dateString: $_temp0, $photos foto.';
  }

  @override
  String restoreReplaceWarning(int current) {
    String _temp0 = intl.Intl.pluralLogic(
      current,
      locale: localeName,
      other: '$current spese',
      one: '1 spesa',
    );
    return 'Tutti i dati attuali ($_temp0, categorie, conti, limiti) verranno sostituiti. Se vuoi tenerli, esportali prima.';
  }

  @override
  String get replace => 'Sostituisci';

  @override
  String restoreDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Dati ripristinati: $count spese',
      one: 'Dati ripristinati: 1 spesa',
    );
    return '$_temp0';
  }

  @override
  String restoreFailed(String error) {
    return 'Ripristino non riuscito: $error';
  }

  @override
  String get backupNotZip => 'Il file non è uno zip valido.';

  @override
  String get backupNotReceipt => 'Questo zip non è un backup di Receipt.';

  @override
  String get backupDamaged => 'Il backup è danneggiato (manifest illeggibile).';

  @override
  String get backupNewer =>
      'Il backup viene da una versione più nuova dell\'app: aggiorna Receipt e riprova.';

  @override
  String get autoBackup => 'Backup automatico cifrato';

  @override
  String get comingSoon => 'In arrivo';

  @override
  String get loadDemo => 'Carica dati di prova';

  @override
  String get loadDemoHint =>
      'Spese inventate a ottobre e settembre 2026, con alcuni limiti';

  @override
  String get hidePassword => 'Nascondi';

  @override
  String get showPassword => 'Mostra';

  @override
  String get passwordTooShort => 'Almeno 4 caratteri';

  @override
  String get passwordsMismatch => 'Le password non coincidono';

  @override
  String get useBiometricTitle => 'Vuoi usare l\'impronta?';

  @override
  String get useBiometricMessage =>
      'Potrai aprire Receipt con l\'impronta invece di scrivere ogni volta la password. La password resta valida e la puoi sempre usare.';

  @override
  String get useBiometric => 'Usa l\'impronta';

  @override
  String get notNow => 'Non ora';

  @override
  String get setupTitle => 'Proteggi le tue spese';

  @override
  String get setupMessage =>
      'Scegli una password per aprire Receipt. Non c\'è modo di recuperarla: tienila a mente o salvala nel tuo gestore di password.';

  @override
  String get password => 'Password';

  @override
  String get repeatPassword => 'Ripeti la password';

  @override
  String get continueLabel => 'Continua';

  @override
  String get wrongPassword => 'Password sbagliata';

  @override
  String get lockedTitle => 'Receipt è bloccata';

  @override
  String get lockedMessage => 'Inserisci la password per continuare.';

  @override
  String tooManyAttempts(int seconds) {
    return 'Troppi tentativi: riprova tra $seconds s';
  }

  @override
  String get unlock => 'Sblocca';

  @override
  String get biometricPromptUnlock => 'Sblocca Receipt';

  @override
  String get biometricPromptConfirm =>
      'Conferma l\'impronta per sbloccare Receipt';

  @override
  String get biometricUsePassword => 'Usa la password';

  @override
  String get ocrTitle => 'Lettore scontrini';

  @override
  String get copyText => 'Copia testo';

  @override
  String get textCopied => 'Testo copiato';

  @override
  String get takePhoto => 'Scatta';

  @override
  String get gallery => 'Galleria';

  @override
  String get ocrIntro =>
      'Il testo viene letto con RapidOCR direttamente sul telefono, senza connessione.';

  @override
  String ocrLines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count righe',
      one: '1 riga',
    );
    return '$_temp0';
  }

  @override
  String get ocrBoxes => 'Riquadri';

  @override
  String updateAvailable(String version, String size) {
    return 'È disponibile Receipt $version ($size)';
  }

  @override
  String get updateLater => 'Non ora';

  @override
  String get updateNow => 'Aggiorna';

  @override
  String updateTitle(String version) {
    return 'Aggiornamento a $version';
  }

  @override
  String get updateDownloading => 'Scarico l\'aggiornamento…';

  @override
  String updateProgress(String done, String total) {
    return '$done di $total';
  }

  @override
  String get updatePermission =>
      'Per installare l\'aggiornamento Android chiede di consentire a Receipt di installare app. Serve solo la prima volta.';

  @override
  String get updateAllow => 'Consenti';

  @override
  String get updateInstalling =>
      'Si apre l\'installer di Android: tocca «Aggiorna» per finire. Spese e foto restano dove sono.';

  @override
  String get updateErrorNetwork =>
      'Download non riuscito. Controlla la connessione e riprova.';

  @override
  String get updateErrorCorrupted =>
      'Il file scaricato non corrisponde a quello pubblicato ed è stato scartato. Riprova.';

  @override
  String get retry => 'Riprova';

  @override
  String get close => 'Chiudi';

  @override
  String get sectionUpdates => 'Aggiornamenti';

  @override
  String get updateCheckOnStart => 'Controlla all\'avvio';

  @override
  String get updateCheckOnStartHint =>
      'Legge la versione disponibile dal sito di Receipt. Non viene inviato nessun tuo dato.';

  @override
  String get updateCheckNow => 'Controlla ora';

  @override
  String updateInstalledVersion(String version) {
    return 'Versione installata: $version';
  }

  @override
  String get updateUpToDate => 'Hai già l\'ultima versione';

  @override
  String get updateCheckFailed =>
      'Non riesco a controllare gli aggiornamenti: sei connesso?';

  @override
  String get scanRecovered =>
      'Android aveva chiuso Receipt mentre scattavi: ecco la foto, la leggo ora.';
}
