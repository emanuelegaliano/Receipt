import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_services.dart';
import 'data/database.dart';
import 'receipt/receipt_scanner.dart';
import 'security/app_lock.dart';
import 'security/lock_screens.dart';
import 'ui/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('it_IT');

  final db = AppDatabase();
  final appearance = ValueNotifier(await AppearanceSettings.load(db));
  final lock = AppLock();
  await lock.init();
  Future<ReceiptScanner>? scanner;
  Future<ReceiptScanner> loadScanner() => scanner ??= ReceiptScanner.load();
  runApp(AppServices(
    db: db,
    month: ValueNotifier(monthOf(DateTime.now())),
    appearance: appearance,
    lock: lock,
    scanner: loadScanner,
    child: const ReceiptApp(),
  ));
  _cleanOrphanReceipts(db);
  // Carica e scalda i modelli OCR in sottofondo, dopo che la prima schermata
  // è comparsa: quando si scatta il primo scontrino sono già pronti.
  Future<void>.delayed(const Duration(seconds: 2), () => loadScanner().ignore());
}

/// Cancella le foto di scontrini non più legate a una spesa (es. eliminate
/// con lo swipe). Solo quelle vecchie di un giorno, per non toccare foto
/// appena salvate o un "Annulla" in corso.
Future<void> _cleanOrphanReceipts(AppDatabase db) async {
  try {
    final dir = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'receipts'));
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
          locale: const Locale('it', 'IT'),
          supportedLocales: const [Locale('it', 'IT')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const HomeShell(),
        );
      },
    );
  }
}
