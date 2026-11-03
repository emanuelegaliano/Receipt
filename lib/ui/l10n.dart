import 'package:flutter/widgets.dart';

import '../data/backup.dart';
import '../data/database.dart';
import '../l10n/app_localizations.dart';

export '../l10n/app_localizations.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// Lingua attuale dell'app per DateFormat e NumberFormat ("it", "en").
  String get localeTag => Localizations.localeOf(this).toLanguageTag();
}

/// Nome da mostrare per una categoria: quelle predefinite, se l'utente non
/// le ha rinominate, seguono la lingua dell'app.
String categoryLabel(Category c, AppLocalizations l) => switch (c.name) {
      'Spesa' => l.catGroceries,
      'Ristoranti e bar' => l.catRestaurants,
      'Trasporti' => l.catTransport,
      'Casa e bollette' => l.catHome,
      'Salute' => l.catHealth,
      'Shopping' => l.catShopping,
      'Svago' => l.catLeisure,
      'Altro' => l.catOther,
      _ => c.name,
    };

/// Come [categoryLabel], per i conti predefiniti.
String accountLabel(Account a, AppLocalizations l) => switch (a.name) {
      'Carta' => l.accountCard,
      'Contanti' => l.accountCash,
      _ => a.name,
    };

/// Il messaggio per un backup rifiutato. Con il nome del file e, se mancano
/// dei file, quali e cosa c'è nello zip: si capisce subito se è stato scelto
/// il file sbagliato o se lo zip è stato rifatto.
String backupErrorText(BackupException e, AppLocalizations l, {required String file}) => switch (e.error) {
      BackupError.notZip => l.backupNotZipNamed(file),
      BackupError.notReceiptBackup when e.missing.isNotEmpty =>
        l.backupNotReceiptDetail(file, e.missing.join(', '), e.found.isEmpty ? '—' : e.found.join(', ')),
      BackupError.notReceiptBackup => l.backupNotReceipt,
      BackupError.damaged => l.backupDamaged,
      BackupError.newerVersion => l.backupNewer,
    };

/// Preposizione per "a settembre" / "ad agosto" nei messaggi italiani.
String monthPrep(DateTime m) => const {4, 8, 10}.contains(m.month) ? 'ad' : 'a';
