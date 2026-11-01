import 'package:flutter/material.dart';

import 'data/database.dart';
import 'receipt/receipt_scanner.dart';
import 'security/app_lock.dart';

/// Servizi condivisi dall'app: database, scanner (caricato solo al primo
/// uso, perché i modelli OCR pesano), mese selezionato, aspetto e blocco.
class AppServices extends InheritedWidget {
  final AppDatabase db;
  final ValueNotifier<DateTime> month;
  final ValueNotifier<AppearanceSettings> appearance;
  final AppLock lock;
  final Future<ReceiptScanner> Function() scanner;

  const AppServices({
    super.key,
    required this.db,
    required this.month,
    required this.appearance,
    required this.lock,
    required this.scanner,
    required super.child,
  });

  static AppServices of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppServices>()!;

  @override
  bool updateShouldNotify(AppServices old) => false;
}

/// Primo giorno del mese di [d].
DateTime monthOf(DateTime d) => DateTime(d.year, d.month);
DateTime nextMonth(DateTime m) => DateTime(m.year, m.month + 1);

/// Colori d'accento tra cui scegliere; il primo è quello predefinito.
/// I nomi sono in AppLocalizations (accentGreen, accentBlue, ...).
const accentColors = <Color>[
  Color(0xFF2E7D5B),
  Color(0xFF2F6FB5),
  Color(0xFF6E52B5),
  Color(0xFFB54A7A),
  Color(0xFFC0682B),
  Color(0xFF55606A),
];

/// Lingue dell'app; "system" segue il telefono.
const appLanguages = ['system', 'it', 'en'];

/// Tema chiaro/scuro, colore d'accento e lingua, salvati nelle impostazioni.
class AppearanceSettings {
  final ThemeMode mode;
  final int accent;
  final String language;
  const AppearanceSettings({this.mode = ThemeMode.system, this.accent = 0, this.language = 'system'});

  Color get seed => accentColors[accent.clamp(0, accentColors.length - 1)];

  /// null = lingua del telefono.
  Locale? get locale => language == 'system' ? null : Locale(language);

  static Future<AppearanceSettings> load(AppDatabase db) async {
    final mode = await db.setting('theme_mode');
    final accent = int.tryParse(await db.setting('theme_accent') ?? '') ?? 0;
    final language = await db.setting('app_lang');
    return AppearanceSettings(
      mode: ThemeMode.values.firstWhere((m) => m.name == mode, orElse: () => ThemeMode.system),
      accent: accent,
      language: appLanguages.contains(language) ? language! : 'system',
    );
  }

  Future<void> save(AppDatabase db) async {
    await db.setSetting('theme_mode', mode.name);
    await db.setSetting('theme_accent', '$accent');
    await db.setSetting('app_lang', language);
  }

  AppearanceSettings copyWith({ThemeMode? mode, int? accent, String? language}) => AppearanceSettings(
      mode: mode ?? this.mode, accent: accent ?? this.accent, language: language ?? this.language);
}
