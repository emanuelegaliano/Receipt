import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_app/app_services.dart';
import 'package:receipt_app/art/daily_art.dart';
import 'package:receipt_app/data/database.dart';
import 'package:receipt_app/data/demo_data.dart';
import 'package:receipt_app/data/photos.dart';
import 'package:receipt_app/island/scene.dart';
import 'package:receipt_app/island/island_service.dart';
import 'package:receipt_app/island/island_ui.dart';
import 'package:receipt_app/l10n/app_localizations.dart';
import 'package:receipt_app/security/app_lock.dart';
import 'package:receipt_app/security/vault.dart';
import 'package:receipt_app/ui/categories_screen.dart';
import 'package:receipt_app/ui/color_wheel.dart';
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
    await tester.pumpWidget(
      AppServices(
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
      ),
    );
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
    await tester
        .pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 2))
        .catchError((_) => 0); // il battito dei posti liberi non si ferma mai
    expect(find.text('Tocca un posto libero sull\'isola'), findsOneWidget);

    // Il posto 2 dell'isola da 3 (davanti a destra).
    final canvas = find.byWidgetPredicate((w) => w is CustomPaint && w.painter is IslandPainter);
    final box = tester.getRect(canvas);
    final fit = PixelFit.forWidth(box.width, 3);
    final (sx, sy) = IslandGeometry(fit.width, 3).slot(2);
    await tester.runAsync(() async {
      await tester.tapAt(box.topLeft + Offset(sx * fit.scale, sy * fit.scale));
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

  testWidgets('con più isole si passa all\'anno prima con la freccia o con i pallini', (tester) async {
    await tester.runAsync(() async {
      await island.init();
      await loadDemoIsland(db);
      await island.refresh();
    });
    await pumpApp(tester, const IslandScreen());
    await tester.pumpAndSettle();
    expect(find.text('Isola 2026'), findsOneWidget);
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right)).onPressed, isNull);
    await tester.tap(find.byTooltip("Isola dell'anno prima"));
    await tester.pumpAndSettle();
    expect(find.text('Isola 2025'), findsOneWidget);
    expect(find.textContaining('Premio dell\'anno'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Isola 2026'));
    await tester.pumpAndSettle();
    expect(find.text('Isola 2026'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('limiti messi dopo il 5: il mese dice da quando valgono, non di metterne uno', (tester) async {
    await tester.runAsync(() async {
      await island.init();
      final cat = (await db.allCategories()).first;
      await db.saveCategory(CategoriesCompanion(id: Value(cat.id), monthlyLimitCents: const Value(20000)));
      await island.refresh();
    });
    await pumpApp(tester, const IslandScreen());
    await tester.pumpAndSettle();
    expect(find.text("Per l'isola questo mese non ci sono limiti: quelli impostati dopo il 5 valgono da dicembre."),
        findsOneWidget);
    expect(find.text('Per piantare serve almeno un limite mensile: impostalo in Categorie.'), findsNothing);
    await finish(tester);
  });

  testWidgets('anche il colore di una categoria si sceglie dal cerchio', (tester) async {
    final cat = (await tester.runAsync(db.allCategories))!.first;
    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) =>
              TextButton(onPressed: () => showCategoryEditor(context, category: cat), child: const Text('modifica')),
        ),
      ),
    );
    await tester.tap(find.text('modifica'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Altro colore'));
    await tester.tap(find.byTooltip('Altro colore'));
    await tester.pumpAndSettle();
    // Il blu sta a 240°, in alto a sinistra.
    final wheel = tester.getRect(find.byType(ColorWheel));
    await tester.tapAt(wheel.center + Offset(-0.5, -0.866) * (wheel.width / 2 - 3));
    await tester.pump();
    await tester.tap(find.text('Usa'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Salva'));
    await tester.runAsync(() async {
      await tester.tap(find.text('Salva'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    final saved = (await tester.runAsync(db.allCategories))!.firstWhere((c) => c.id == cat.id);
    expect(HSVColor.fromColor(Color(saved.color)).hue, closeTo(240, 3));
    await finish(tester);
  });

  testWidgets('il catalogo mostra tutte le piante con la stagione', (tester) async {
    await pumpApp(
      tester,
      Builder(
        builder: (context) => TextButton(onPressed: () => showPlantPicker(context), child: const Text('apri')),
      ),
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
    expect(find.textContaining('per novembre restano quelli di inizio mese'), findsOneWidget);
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
