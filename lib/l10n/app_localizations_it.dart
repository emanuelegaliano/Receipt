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
  String get accentCustom => 'Altro colore';

  @override
  String get customColorTitle => 'Scegli il colore';

  @override
  String get useColor => 'Usa';

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
      'Spese, foto e lettura degli scontrini non lasciano mai il dispositivo. Spese e foto sono cifrate con la tua password.';

  @override
  String get exportData => 'Esporta i dati';

  @override
  String get exportDataHint =>
      'Database e foto in un file .zip da salvare dove vuoi, es. su Drive. Il file non è cifrato: serve la password per crearlo.';

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
      'Spese inventate a ottobre e settembre 2026 con qualche limite, e due isole piene';

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
      'Scegli una password per aprire Receipt: spese e foto vengono cifrate con questa. Non c\'è modo di recuperarla: tienila a mente o salvala nel tuo gestore di password.';

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

  @override
  String get chooseMonth => 'Vai al mese';

  @override
  String get thisMonth => 'Questo mese';

  @override
  String get previousYear => 'Anno precedente';

  @override
  String get nextYear => 'Anno successivo';

  @override
  String get updateConsentTitle => 'Aggiornamenti automatici';

  @override
  String get updateConsentMessage =>
      'Receipt funziona tutta sul telefono e non raccoglie i tuoi dati. Vuoi che a ogni apertura controlli su internet se c\'è una nuova versione? Legge solo il numero di versione dal sito di Receipt. Puoi cambiare idea nelle Impostazioni.';

  @override
  String get updateConsentNo => 'No, grazie';

  @override
  String get updateConsentYes => 'Sì, controlla';

  @override
  String get dailyArt => 'Quadro del giorno';

  @override
  String get dailyArtHint =>
      'Ogni giorno un dipinto del Metropolitan Museum of Art come sfondo, tra 600 di pubblico dominio. Scarica un\'immagine al giorno da Wikimedia Commons (circa 0,7 MB); nessun tuo dato viene inviato.';

  @override
  String get dailyArtDownloading => 'Scarico il quadro di oggi…';

  @override
  String get dailyArtFailed =>
      'Non sono riuscito a scaricare il quadro di oggi: riprovo quando torni nell\'app.';

  @override
  String dailyArtToday(String title, String artist) {
    return 'Oggi: $title, $artist. Tocca la «i» in alto per saperne di più.';
  }

  @override
  String get paintingOfTheDay => 'Il quadro di oggi';

  @override
  String get paintingDate => 'Data';

  @override
  String get paintingMedium => 'Tecnica';

  @override
  String get paintingDimensions => 'Misure';

  @override
  String paintingCredit(String credit) {
    return 'The Metropolitan Museum of Art, New York. $credit';
  }

  @override
  String get paintingOpenMet => 'Pagina del Met';

  @override
  String paintingFromWikipedia(String title) {
    return 'Da Wikipedia, voce «$title» (CC BY-SA 4.0)';
  }

  @override
  String get paintingFromWikidata => 'Da Wikidata (CC0)';

  @override
  String paintingSources(String license) {
    return 'Dati dell\'opera: Open Access del Met e Wikidata (CC0). Immagine: Wikimedia Commons ($license).';
  }

  @override
  String get paintingOpenWikipedia => 'Wikipedia';

  @override
  String get paintingOpenCommons => 'Immagine su Commons';

  @override
  String get dailyArtConsentMessage =>
      'Vuoi come sfondo un dipinto del Metropolitan Museum of Art, diverso ogni giorno? Receipt scarica un\'immagine al giorno da Wikimedia Commons (circa 0,7 MB) e non invia nessun tuo dato. Puoi cambiare idea nelle Impostazioni.';

  @override
  String get dailyArtConsentInternet =>
      'Hai scelto di non far usare internet a Receipt per gli aggiornamenti. Il quadro del giorno ha bisogno di internet: attivandolo, l\'app si collegherà solo per scaricare l\'immagine di oggi.';

  @override
  String get dailyArtConsentYes => 'Sì, attiva';

  @override
  String dailyArtVisibility(String percent) {
    return 'Visibilità del quadro: $percent%';
  }

  @override
  String backupNotZipNamed(String file) {
    return '«$file» non è uno zip valido.';
  }

  @override
  String backupNotReceiptDetail(String file, String missing, String found) {
    return '«$file» non è un backup di Receipt: non trovo $missing. Nello zip c\'è: $found.';
  }

  @override
  String get lockedUpgradeMessage =>
      'Questa volta serve la password, non l\'impronta: da questa versione Receipt la usa per cifrare spese e foto sul telefono.';

  @override
  String get biometricChangedMessage =>
      'Le impronte del telefono sono cambiate: entra con la password, poi potrai riattivare l\'impronta.';

  @override
  String get biometricConfirmTitle => 'Continuare con l\'impronta?';

  @override
  String get biometricConfirmMessage =>
      'Spese e foto sono cifrate con la tua password. Per aprirle anche con l\'impronta, confermala una volta.';

  @override
  String get exportPasswordTitle => 'Conferma con la password';

  @override
  String get exportPasswordMessage =>
      'Il file esportato non è cifrato: chi lo apre vede spese e foto. Per crearlo serve la password.';

  @override
  String get exportAction => 'Esporta';

  @override
  String get updateWhatsNew => 'Cosa c\'è di nuovo';

  @override
  String updateDownloadSize(String size) {
    return 'Download di $size';
  }

  @override
  String get islandTooltip => 'La tua isola';

  @override
  String islandTitle(String year) {
    return 'Isola $year';
  }

  @override
  String get islandHowTitle => 'Come funziona';

  @override
  String get islandHowBody =>
      'Ogni mese in cui resti nei limiti puoi piantare qualcosa sull\'isola: scegli tu cosa e dove.\n\nConta il totale delle categorie che hanno un limite: se una sfora ma le altre compensano, il mese vale lo stesso. Serve almeno un limite.\n\nIl mese deve essere registrato con la regolarità di sempre: non registrare non è risparmiare. Conta la data della spesa, non quando la inserisci.\n\nValgono i limiti del giorno 5: se li cambi dopo, per l\'isola contano dal mese successivo.\n\nOgni anno è un\'isola nuova. Se a fine anno hai piantato più di metà dei posti, al centro spunta una sorpresa.';

  @override
  String get islandPreviousYear => 'Isola dell\'anno prima';

  @override
  String get islandNextYear => 'Isola dell\'anno dopo';

  @override
  String islandPendingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hai $count piante da mettere',
      one: 'Hai una pianta da mettere',
    );
    return '$_temp0';
  }

  @override
  String islandChoosePlant(String month) {
    return 'Scegli la pianta di $month';
  }

  @override
  String islandGiftNote(String month) {
    return 'La pianta di $month è un regalo, per vedere come funziona.';
  }

  @override
  String get islandTapSpot => 'Tocca un posto libero sull\'isola';

  @override
  String islandPlaced(String plant) {
    return '$plant è sull\'isola';
  }

  @override
  String get islandPlantFailed =>
      'Non si può piantare: qualcosa è cambiato, riprova.';

  @override
  String get islandPickerTitle => 'Cosa vuoi piantare?';

  @override
  String get islandGroupTree => 'Alberi';

  @override
  String get islandGroupFruitTree => 'Alberi da frutto';

  @override
  String get islandGroupConifer => 'Conifere';

  @override
  String get islandGroupPalm => 'Palme';

  @override
  String get islandGroupShrub => 'Arbusti';

  @override
  String get islandGroupFlower => 'Fiori';

  @override
  String get islandGroupSucculent => 'Piante grasse';

  @override
  String islandBlooms(String range) {
    return 'Fiorisce $range';
  }

  @override
  String islandFruits(String range) {
    return 'Frutti $range';
  }

  @override
  String get islandFruitsAllYear => 'Frutti tutto l\'anno';

  @override
  String get islandEvergreen => 'Sempreverde';

  @override
  String get islandDeciduous => 'Spoglio d\'inverno';

  @override
  String get islandGiftLabel => 'regalo';

  @override
  String islandRewardProgress(int planted, int needed) {
    return 'Piante: $planted su $needed. Con $needed a fine anno, al centro spunta una sorpresa.';
  }

  @override
  String get islandRewardReady =>
      'Ci sei: a fine anno al centro spunta una sorpresa.';

  @override
  String islandRewardEarned(String name) {
    return 'Premio dell\'anno: $name';
  }

  @override
  String islandRewardMissed(int needed) {
    return 'Quest\'anno niente premio: servivano $needed piante.';
  }

  @override
  String get islandComplete => 'Isola completa!';

  @override
  String islandCurrentMonth(String month, String spent, String limit) {
    return '$month finora: $spent su $limit';
  }

  @override
  String get islandCurrentOver =>
      'Sei oltre i limiti: questo mese niente pianta.';

  @override
  String islandCurrentGap(int days, int max) {
    return '$days giorni di fila senza spese: per il mese il massimo è $max.';
  }

  @override
  String get islandCurrentOk => 'Registrazioni regolari';

  @override
  String get islandNoLimits =>
      'Per piantare serve almeno un limite mensile: impostalo in Categorie.';

  @override
  String islandNoLimitsThisMonth(String month) {
    return 'Per l\'isola questo mese non ci sono limiti: quelli impostati dopo il 5 valgono da $month.';
  }

  @override
  String get islandMonthPending => 'Da piantare';

  @override
  String islandMonthOver(String spent, String limit) {
    return 'Oltre i limiti: $spent su $limit';
  }

  @override
  String get islandMonthNoLimits => 'Nessun limite';

  @override
  String get islandMonthNoRecords => 'Nessuna spesa registrata';

  @override
  String islandMonthGap(int days) {
    return '$days giorni di fila senza spese';
  }

  @override
  String islandMonthFew(int records, int minimum) {
    return 'Poche spese registrate: $records, ne servivano $minimum';
  }

  @override
  String get islandMonthInProgress => 'In corso';

  @override
  String islandLimitChangeTitle(String month) {
    return 'Per l\'isola vale da $month';
  }

  @override
  String islandLimitChangeBody(String month) {
    return 'I limiti cambiati dopo il 5 contano per l\'isola dal mese successivo: per $month restano quelli di inizio mese. Gli avvisi invece usano subito il nuovo limite.';
  }

  @override
  String get plantOak => 'Quercia';

  @override
  String get plantOlive => 'Ulivo';

  @override
  String get plantMaple => 'Acero';

  @override
  String get plantBirch => 'Betulla';

  @override
  String get plantWillow => 'Salice piangente';

  @override
  String get plantStonePine => 'Pino domestico';

  @override
  String get plantLemon => 'Limone';

  @override
  String get plantOrange => 'Arancio';

  @override
  String get plantApple => 'Melo';

  @override
  String get plantCherry => 'Ciliegio';

  @override
  String get plantAlmond => 'Mandorlo';

  @override
  String get plantFig => 'Fico';

  @override
  String get plantFir => 'Abete';

  @override
  String get plantCypress => 'Cipresso';

  @override
  String get plantDatePalm => 'Palma da dattero';

  @override
  String get plantFanPalm => 'Palma nana';

  @override
  String get plantLavender => 'Lavanda';

  @override
  String get plantRosemary => 'Rosmarino';

  @override
  String get plantOleander => 'Oleandro';

  @override
  String get plantHydrangea => 'Ortensia';

  @override
  String get plantBougainvillea => 'Bouganville';

  @override
  String get plantSunflower => 'Girasole';

  @override
  String get plantPoppy => 'Papavero';

  @override
  String get plantDaisy => 'Margherita';

  @override
  String get plantTulip => 'Tulipano';

  @override
  String get plantRose => 'Rosa';

  @override
  String get plantIris => 'Iris';

  @override
  String get plantJasmine => 'Gelsomino';

  @override
  String get plantPricklyPear => 'Fico d\'India';

  @override
  String get plantAgave => 'Agave';

  @override
  String get plantAloe => 'Aloe';

  @override
  String get plantCactus => 'Cactus';

  @override
  String get centerpieceLighthouse => 'un faro';

  @override
  String get centerpieceFountain => 'una fontana';

  @override
  String get centerpieceTemple => 'un tempietto';

  @override
  String get centerpieceStatue => 'una statua';

  @override
  String get centerpieceObelisk => 'un obelisco';
}
