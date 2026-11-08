import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path_provider/path_provider.dart';

import 'app_services.dart';
import 'art/daily_art.dart';
import 'data/backup.dart';
import 'data/database.dart';
import 'data/photos.dart';
import 'island/island_service.dart';
import 'l10n/app_localizations.dart';
import 'receipt/receipt_scanner.dart';
import 'security/app_lock.dart';
import 'security/lock_screens.dart';
import 'ui/home_shell.dart';
import 'ui/scan_flow.dart';
import 'update/updater.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PaintingBinding.instance.imageCache.maximumSizeBytes = imageCacheBytes;
  await initializeDateFormatting('it');
  await initializeDateFormatting('en');

  final lock = AppLock();
  await lock.init();
  // Database e foto sono cifrati: si aprono quando c'è la chiave, cioè dopo
  // lo sblocco. Le schermate dietro quella di blocco aspettano.
  final db = AppDatabase(openEncryptedDatabase(lock.dataKey, keyIsNew: () => lock.keyIsNew));
  final photos = ReceiptPhotos(lock.dataKey);
  // Il tema della schermata di blocco viene da una copia fuori dal database.
  final appearance = ValueNotifier(await AppearanceSettings.loadCached());
  final art = DailyArt(db);
  final island = IslandService(db);
  Future<ReceiptScanner>? scanner;
  Future<ReceiptScanner> loadScanner() => scanner ??= ReceiptScanner.load();
  runApp(AppServices(
    db: db,
    month: ValueNotifier(monthOf(DateTime.now())),
    appearance: appearance,
    lock: lock,
    photos: photos,
    scanner: loadScanner,
    updater: Updater(),
    art: art,
    island: island,
    child: const ReceiptApp(),
  ));
  _afterUnlock(db, photos, appearance, art, island);
  // Tornando all'app (magari in un mese nuovo) l'isola si ricalcola.
  AppLifecycleListener(onResume: () => island.refresh().ignore());
  // Carica e scalda i modelli OCR in sottofondo, dopo che la prima schermata
  // è comparsa: quando si scatta il primo scontrino sono già pronti.
  Future<void>.delayed(const Duration(seconds: 2), () => loadScanner().ignore());
}

/// Appena c'è la chiave dei dati (la prima await sul database aspetta lo
/// sblocco): impostazioni vere, quadro del giorno, foto.
Future<void> _afterUnlock(AppDatabase db, ReceiptPhotos photos, ValueNotifier<AppearanceSettings> appearance,
    DailyArt art, IslandService island) async {
  final saved = await AppearanceSettings.load(db);
  appearance.value = saved;
  await saved.cache();
  try {
    // Alla prima volta crea l'isola (col regalo) e copia i limiti: subito,
    // prima del quadro del giorno che può aspettare la rete, così nessun
    // limite cambiato nel frattempo passa per "quello del primo avvio".
    await island.init();
  } catch (_) {
    // Riprova quando si apre l'isola.
  }
  await art.init();
  await _cleanOrphanReceipts(db, photos);
  try {
    final cache = await getTemporaryDirectory();
    await deleteOldExports(cache);
    // Copie in chiaro lasciate da image_picker (anche dalla 0.3.4). Quelle
    // recenti no: potrebbe essere la foto che recoverLostScan sta leggendo.
    await deletePickerCopies(cache, olderThan: const Duration(minutes: 10));
    // E quella del backup importato, se l'import si è interrotto.
    await FilePicker.clearTemporaryFiles();
  } catch (_) {
    // Al prossimo avvio.
  }
  try {
    // Dopo l'aggiornamento dalla 0.3.4: le foto ancora in chiaro.
    await photos.encryptLeftovers();
  } catch (_) {
    // Riprova al prossimo avvio; intanto le foto in chiaro si leggono lo stesso.
  }
}

/// Cancella le foto di scontrini non più legate a una spesa (es. eliminate
/// con lo swipe). Solo quelle vecchie di un giorno, per non toccare foto
/// appena salvate o un "Annulla" in corso.
Future<void> _cleanOrphanReceipts(AppDatabase db, ReceiptPhotos photos) async {
  try {
    final dir = await photos.directory();
    if (!await dir.exists()) return;
    final used = await db.receiptPaths();
    final limit = DateTime.now().subtract(const Duration(days: 1));
    await for (final f in dir.list()) {
      if (f is File && !used.contains(f.path) && (await f.lastModified()).isBefore(limit)) await f.delete();
    }
  } catch (_) {
    // Non è un problema se la pulizia salta: riproverà al prossimo avvio.
  }
}

class ReceiptApp extends StatelessWidget {
  const ReceiptApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: AppServices.of(context).appearance,
      builder: (context, appearance, _) {
        ThemeData theme(Brightness b) {
          final base = ThemeData(colorSchemeSeed: appearance.seed, brightness: b, useMaterial3: true);
          return base.copyWith(
            inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
            cardTheme: base.cardTheme.copyWith(margin: EdgeInsets.zero),
          );
        }

        return MaterialApp(
          title: 'Receipt',
          debugShowCheckedModeBanner: false,
          theme: theme(Brightness.light),
          darkTheme: theme(Brightness.dark),
          themeMode: appearance.mode,
          builder: (context, child) => LockGate(lock: AppServices.of(context).lock, child: child!),
          locale: appearance.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          // Con la lingua di sistema: italiano solo se il telefono è in
          // italiano, altrimenti inglese.
          localeResolutionCallback: (device, _) => device?.languageCode == 'it' ? const Locale('it') : const Locale('en'),
          home: const HomeShell(),
        );
      },
    );
  }
}
