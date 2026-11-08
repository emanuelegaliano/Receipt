import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_app/app_services.dart';
import 'package:receipt_app/art/daily_art.dart';
import 'package:receipt_app/data/database.dart';
import 'package:receipt_app/data/photos.dart';
import 'package:receipt_app/island/island_painter.dart';
import 'package:receipt_app/island/island_service.dart';
import 'package:receipt_app/island/island_ui.dart';
import 'package:receipt_app/l10n/app_localizations.dart';
import 'package:receipt_app/security/app_lock.dart';
import 'package:receipt_app/security/vault.dart';
import 'package:receipt_app/update/updater.dart';

void main() {
  late DateTime now;
  late AppDatabase db;
  late IslandService island;

  setUp(() {
    now = DateTime(2026, 11, 8, 10);
    db = AppDatabase(NativeDatabase.memory(), clock: () => now);
    island = IslandService(db);
  });

  Future<void> pumpApp(WidgetTester tester, Widget home, {Brightness brightness = Brightness.light}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(AppServices(
      db: db,
      month: ValueNotifier(monthOf(now)),
      appearance: ValueNotifier(const AppearanceSettings(language: 'it')),
      lock: AppLock(),
      photos: ReceiptPhotos(Future.value(DataKey.random())),
      scanner: () => throw UnimplementedError(),
      updater: Updater(),
      art: DailyArt(db),
      island: island,
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        locale: const Locale('it'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: home,
      ),
    ));
  }

  Future<void> finish(WidgetTester tester) async {
    island.dispose();
    await tester.pumpWidget(const SizedBox());
    await db.close();
  }

  testWidgets('dal pallino nel Riepilogo alla pianta regalata sull\'isola', (tester) async {
    await tester.runAsync(island.init);
    await pumpApp(tester, Scaffold(appBar: AppBar(actions: const [IslandButton()])));
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isTrue);

    await tester.tap(find.byType(IslandButton));
    await tester.pumpAndSettle();
    expect(find.text('Isola 2026'), findsOneWidget);
    expect(find.text('Hai una pianta da mettere'), findsOneWidget);
    expect(find.text('La pianta di ottobre è un regalo, per vedere come funziona.'), findsOneWidget);
    expect(find.text('Per piantare serve almeno un limite mensile: impostalo in Categorie.'), findsOneWidget);

    await tester.tap(find.text('Scegli la pianta di ottobre'));
    await tester.pumpAndSettle();
    expect(find.text('Cosa vuoi piantare?'), findsOneWidget);
    await tester.tap(find.text('Ulivo'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 2))
        .catchError((_) => 0); // il battito dei posti liberi non si ferma mai
    expect(find.text('Tocca un posto libero sull\'isola'), findsOneWidget);

    // Il posto 2 dell'isola da 3 (davanti a destra).
    final canvas = find.byWidgetPredicate((w) => w is CustomPaint && w.painter is IslandPainter);
    final box = tester.getRect(canvas);
    final layout = IslandLayout(box.size, 3);
    await tester.runAsync(() async {
      await tester.tapAt(box.topLeft + layout.slot(2));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Ulivo è sull\'isola'), findsOneWidget);
    final planted = island.state!.years.single.bySlot[2]!;
    expect((planted.month, planted.plant, planted.gift), (202610, 'olive', true));
    expect(find.text('Hai una pianta da mettere'), findsNothing);
    expect(find.text('Ulivo · regalo'), findsOneWidget, reason: 'nella lista dei mesi');

    Navigator.of(tester.element(find.text('Isola 2026'))).pop();
    await tester.pumpAndSettle();
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
    await finish(tester);
  });

  testWidgets('il catalogo mostra tutte le piante con la stagione', (tester) async {
    await pumpApp(
      tester,
      Builder(builder: (context) => TextButton(onPressed: () => showPlantPicker(context), child: const Text('apri'))),
      brightness: Brightness.dark,
    );
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();
    expect(find.text('Alberi'), findsOneWidget);
    expect(find.text('Mandorlo'), findsOneWidget);
    expect(find.text('Fiorisce febbraio–marzo'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Aloe'), 300, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    expect(find.text('Aloe'), findsOneWidget);
    expect(find.text('Fiorisce dicembre–febbraio'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('cambiare un limite dopo il 5 chiede conferma, prima no', (tester) async {
    bool? answer;
    await pumpApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => answer = await confirmLimitChangeForIsland(context, now),
          child: const Text('salva'),
        ),
      ),
    );
    await tester.tap(find.text('salva'));
    await tester.pumpAndSettle();
    expect(find.text('Per l\'isola vale da dicembre'), findsOneWidget);
    expect(find.textContaining('per novembre resta quello di prima'), findsOneWidget);
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(answer, isFalse);

    now = DateTime(2026, 11, 5, 23);
    await tester.tap(find.text('salva'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(answer, isTrue);
    await finish(tester);
  });
}
