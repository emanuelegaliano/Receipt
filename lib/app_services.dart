import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'art/daily_art.dart';
import 'data/database.dart';
import 'data/photos.dart';
import 'island/island_service.dart';
import 'receipt/receipt_scanner.dart';
import 'security/app_lock.dart';
import 'update/updater.dart';

/// Servizi condivisi dall'app: database, foto, scanner (caricato solo al
/// primo uso, perché i modelli OCR pesano), mese selezionato, aspetto,
/// blocco, aggiornamenti, quadro del giorno e isola.
class AppServices extends InheritedWidget {
  final AppDatabase db;
  final ValueNotifier<DateTime> month;
  final ValueNotifier<AppearanceSettings> appearance;
  final AppLock lock;
  final ReceiptPhotos photos;
  final Future<ReceiptScanner> Function() scanner;
  final Updater updater;
  final DailyArt art;
  final IslandService island;

  const AppServices({
    super.key,
    required this.db,
    required this.month,
    required this.appearance,
    required this.lock,
    required this.photos,
    required this.scanner,
    required this.updater,
    required this.art,
    required this.island,
    required super.child,
  });

  static AppServices of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppServices>()!;

  @override
  bool updateShouldNotify(AppServices old) => false;
}

/// Limite della cache delle immagini decodificate. Le foto degli scontrini
/// sono le uniche immagini grandi e servono una volta sola: con i 100 MB del
/// default restavano occupate per niente.
const imageCacheBytes = 32 << 20;

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

  /// Un colore scelto col cerchio dei colori (ARGB); se c'è, vale al posto di [accent].
  final int? custom;
  final String language;
  const AppearanceSettings({this.mode = ThemeMode.system, this.accent = 0, this.custom, this.language = 'system'});

  Color get seed => custom != null ? Color(custom!) : accentColors[accent.clamp(0, accentColors.length - 1)];

  /// null = lingua del telefono.
  Locale? get locale => language == 'system' ? null : Locale(language);

  static Future<AppearanceSettings> load(AppDatabase db) async {
    final mode = await db.setting('theme_mode');
    final accent = int.tryParse(await db.setting('theme_accent') ?? '') ?? 0;
    final custom = int.tryParse(await db.setting('theme_custom') ?? '', radix: 16);
    final language = await db.setting('app_lang');
    return AppearanceSettings(
      mode: ThemeMode.values.firstWhere((m) => m.name == mode, orElse: () => ThemeMode.system),
      accent: accent,
      custom: custom,
      language: appLanguages.contains(language) ? language! : 'system',
    );
  }

  Future<void> save(AppDatabase db) async {
    await db.setSetting('theme_mode', mode.name);
    await db.setSetting('theme_accent', '$accent');
    await db.setSetting('theme_custom', custom?.toRadixString(16) ?? '');
    await db.setSetting('app_lang', language);
    await cache();
  }

  Map<String, Object> toJson() => {'mode': mode.name, 'accent': accent, 'custom': ?custom, 'language': language};

  static AppearanceSettings fromJson(Map<String, dynamic> json) => AppearanceSettings(
    mode: ThemeMode.values.firstWhere((m) => m.name == json['mode'], orElse: () => ThemeMode.system),
    accent: json['accent'] is int ? json['accent'] as int : 0,
    custom: json['custom'] is int ? json['custom'] as int : null,
    language: appLanguages.contains(json['language']) ? json['language'] as String : 'system',
  );

  /// Copia non cifrata di tema, colore e lingua, per la schermata di blocco
  /// (il database si apre solo dopo). Non contiene niente di personale.
  static Future<File> _cacheFile() async =>
      File(p.join((await getApplicationSupportDirectory()).path, 'appearance.json'));

  Future<void> cache() async {
    try {
      await (await _cacheFile()).writeAsString(jsonEncode(toJson()));
    } on FileSystemException {
      // Al prossimo avvio la schermata di blocco avrà il tema di sistema.
    }
  }

  static Future<AppearanceSettings> loadCached() async {
    try {
      return fromJson(jsonDecode(await (await _cacheFile()).readAsString()) as Map<String, dynamic>);
    } catch (_) {
      return const AppearanceSettings();
    }
  }

  /// Cambia tema o lingua; il colore resta quello che è.
  AppearanceSettings copyWith({ThemeMode? mode, String? language}) =>
      AppearanceSettings(mode: mode ?? this.mode, accent: accent, custom: custom, language: language ?? this.language);

  /// Uno dei colori proposti: toglie quello scelto col cerchio.
  AppearanceSettings withAccent(int accent) => AppearanceSettings(mode: mode, accent: accent, language: language);

  /// Un colore scelto col cerchio.
  AppearanceSettings withCustom(Color color) =>
      AppearanceSettings(mode: mode, accent: accent, custom: color.toARGB32(), language: language);
}
