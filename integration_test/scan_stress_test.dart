import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:receipt_app/app_services.dart';
import 'package:receipt_app/art/daily_art.dart';
import 'package:receipt_app/data/database.dart';
import 'package:receipt_app/l10n/app_localizations.dart';
import 'package:receipt_app/receipt/receipt_scanner.dart';
import 'package:receipt_app/security/app_lock.dart';
import 'package:receipt_app/ui/expense_form_screen.dart';
import 'package:receipt_app/ui/home_shell.dart';
import 'package:receipt_app/ui/scan_flow.dart';
import 'package:receipt_app/update/updater.dart';

/// Tanti scontrini di fila, come chi registra la spesa della settimana:
/// scansione -> modulo -> Salva, ripetuto, stampando la memoria del processo.
///
/// Le foto arrivano via HTTP dal Mac (vedi sroie_benchmark_test.dart):
///   python3 -m http.server 8765 --bind 127.0.0.1   (nella cartella con img/)
///   adb reverse tcp:8765 tcp:8765
///   flutter test integration_test/scan_stress_test.dart [--dart-define=ROUNDS=30]
/// Stampa `STRESS {giro} rss=... MB` a ogni giro.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const host = String.fromEnvironment('SAMPLES_HOST', defaultValue: 'http://127.0.0.1:8765');
  const rounds = int.fromEnvironment('ROUNDS', defaultValue: 30);
  // Secondi di attesa alla fine con l'app viva, per aprire la fotocamera da
  // adb e vedere se Android uccide il processo in sottofondo.
  const hold = int.fromEnvironment('HOLD', defaultValue: 0);

  testWidgets('scontrini di fila', timeout: const Timeout(Duration(hours: 2)), (tester) async {
    final client = HttpClient();
    Future<Uint8List> get(String path) async {
      final res = await (await client.getUrl(Uri.parse('$host/$path'))).close();
      return Uint8List.fromList(await consolidateHttpClientResponseBytes(res));
    }

    final listing = String.fromCharCodes(await get('img/'));
    final names = RegExp(r'href="([^"]+\.jpg)"').allMatches(listing).map((m) => m[1]!).toList()..sort();
    expect(names, isNotEmpty);

    PaintingBinding.instance.imageCache.maximumSizeBytes = imageCacheBytes; // come in main()
    final db = AppDatabase(NativeDatabase.memory());
    await db.setSetting('update_check', 'off');
    final lock = AppLock();
    Future<ReceiptScanner>? scanner;
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(AppServices(
      db: db,
      month: ValueNotifier(monthOf(DateTime.now())),
      appearance: ValueNotifier(const AppearanceSettings(language: 'it')),
      lock: lock,
      scanner: () => scanner ??= ReceiptScanner.load(),
      updater: Updater(),
      art: DailyArt(db), // spento: nessuna impostazione daily_art
      child: MaterialApp(
        navigatorKey: navigator,
        locale: const Locale('it'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const HomeShell(),
      ),
    ));
    await tester.pumpAndSettle();

    int mb(int bytes) => bytes ~/ (1024 * 1024);
    // ignore: avoid_print
    print('STRESS 0 rss=${mb(ProcessInfo.currentRss)}MB');
    for (var i = 1; i <= rounds; i++) {
      final bytes = await get('img/${names[(i - 1) % names.length]}');
      final sw = Stopwatch()..start();
      // Come startScan() dopo il ritorno dalla fotocamera.
      navigator.currentState!.push(MaterialPageRoute(builder: (_) => ScanProcessingScreen(bytes)));
      // L'OCR gira fuori dal frame: si aspetta finché compare il modulo.
      while (find.byType(ExpenseFormScreen).evaluate().isEmpty) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
        await tester.pump();
        expect(find.textContaining('Non sono riuscito'), findsNothing);
      }
      await tester.pumpAndSettle();
      // Importo mancante: lo si scrive a mano come farebbe l'utente.
      final amount = find.byType(TextFormField).first;
      if ((tester.widget<TextFormField>(amount).controller?.text ?? '').isEmpty) {
        await tester.enterText(amount, '12,34');
      }
      await tester.scrollUntilVisible(find.text('Salva'), 300,
          scrollable: find.descendant(of: find.byType(ExpenseFormScreen), matching: find.byType(Scrollable)).first);
      await tester.tap(find.text('Salva'));
      // Il salvataggio scrive su disco e nel database: si aspetta che il modulo si chiuda.
      for (var t = 0; find.byType(ExpenseFormScreen).evaluate().isNotEmpty; t++) {
        if (t == 100) {
          final texts = [for (final e in find.byType(Text).evaluate()) (e.widget as Text).data];
          fail('il modulo non si chiude dopo Salva: $texts');
        }
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
      // Lo snackbar "Spesa salvata" coprirebbe il Salva del giro dopo.
      ScaffoldMessenger.of(navigator.currentContext!).clearSnackBars();
      await tester.pumpAndSettle();
      // ignore: avoid_print
      print('STRESS $i rss=${mb(ProcessInfo.currentRss)}MB maxRss=${mb(ProcessInfo.maxRss)}MB '
          'ms=${sw.elapsedMilliseconds} imageCache=${mb(PaintingBinding.instance.imageCache.currentSizeBytes)}MB');
    }
    client.close();
    if (hold > 0) {
      // ignore: avoid_print
      print('STRESS_HOLD ${hold}s');
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: hold)));
      // ignore: avoid_print
      print('STRESS_ALIVE rss=${mb(ProcessInfo.currentRss)}MB');
    }
  });
}
