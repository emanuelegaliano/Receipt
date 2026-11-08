import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_app/app_services.dart';
import 'package:receipt_app/data/database.dart';
import 'package:receipt_app/l10n/app_localizations.dart';
import 'package:receipt_app/ui/color_wheel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  setUp(() {
    // save() tiene una copia per la schermata di blocco nella cartella dell'app.
    tmp = Directory.systemTemp.createTempSync('appearance');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'), (call) async => tmp.path);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('un colore scelto col cerchio vale al posto di quelli proposti, e si salva', () async {
    final db = AppDatabase(NativeDatabase.memory());
    const base = AppearanceSettings(mode: ThemeMode.dark, accent: 2, language: 'it');
    expect(base.seed, accentColors[2]);

    final custom = base.withCustom(const Color(0xFF1E88E5));
    expect((custom.seed, custom.accent, custom.mode, custom.language), (const Color(0xFF1E88E5), 2, ThemeMode.dark, 'it'));
    await custom.save(db);
    final loaded = await AppearanceSettings.load(db);
    expect((loaded.custom, loaded.seed), (0xFF1E88E5, const Color(0xFF1E88E5)));
    // Anche la copia per la schermata di blocco.
    expect(AppearanceSettings.fromJson(custom.toJson()).custom, 0xFF1E88E5);
    expect((await AppearanceSettings.loadCached()).custom, 0xFF1E88E5);

    // Cambiare tema o lingua non lo tocca; scegliere un colore proposto lo toglie.
    expect(loaded.copyWith(mode: ThemeMode.light).custom, 0xFF1E88E5);
    final preset = loaded.withAccent(4);
    expect((preset.custom, preset.seed), (null, accentColors[4]));
    await preset.save(db);
    expect((await AppearanceSettings.load(db)).custom, isNull);
    expect(preset.toJson().containsKey('custom'), isFalse);
    expect(AppearanceSettings.fromJson(preset.toJson()).custom, isNull);
    await db.close();
  });

  test('nel cerchio l\'angolo è la tinta e la distanza dal centro la vivacità', () {
    HSVColor at(double x, double y) => HSVColor.fromColor(ColorWheel.colorAt(Offset(x, y), 200));
    expect(at(200, 100).hue, closeTo(0, 1));
    expect(at(200, 100).saturation, closeTo(1, 0.01));
    expect(at(100, 200).hue, closeTo(90, 1), reason: 'in basso, girando in senso orario');
    expect(at(0, 100).hue, closeTo(180, 1));
    expect(at(100, 100).saturation, closeTo(0, 0.01), reason: 'al centro grigio');
    expect(at(150, 100).saturation, closeTo(0.5, 0.02));
    expect(at(400, 100).saturation, closeTo(1, 0.01), reason: 'fuori dal cerchio resta al bordo');
  });

  testWidgets('dalla finestra del cerchio: si tocca un colore e si usa', (tester) async {
    Color? picked;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('it'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => picked = await showColorWheel(context, accentColors[0]),
          child: const Text('apri'),
        ),
      ),
    ));
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();
    expect(find.text('Scegli il colore'), findsOneWidget);
    final wheel = tester.getRect(find.byType(ColorWheel));
    await tester.tapAt(wheel.centerRight - const Offset(2, 0));
    await tester.pump();
    await tester.tap(find.text('Usa'));
    await tester.pumpAndSettle();
    expect(HSVColor.fromColor(picked!).hue, anyOf(closeTo(0, 3), closeTo(360, 3)));

    // Annulla non cambia niente.
    picked = null;
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(picked, isNull);
  });
}
