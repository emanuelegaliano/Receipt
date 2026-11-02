import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:receipt_app/l10n/app_localizations.dart';
import 'package:receipt_app/ui/widgets.dart';

void main() {
  setUpAll(() => initializeDateFormatting('it'));

  /// Apre il selettore; la funzione restituita aspetta la scelta.
  Future<Future<DateTime?> Function()> open(WidgetTester tester, DateTime initial) async {
    DateTime? result;
    var done = false;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('it'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await showMonthPicker(context, initial: initial);
            done = true;
          },
          child: const Text('apri'),
        ),
      ),
    ));
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();
    return () async {
      await tester.pumpAndSettle();
      expect(done, isTrue);
      return result;
    };
  }

  testWidgets('salta a un mese di un altro anno', (tester) async {
    final result = await open(tester, DateTime(2026, 3));
    expect(find.text('2026'), findsOneWidget);
    await tester.tap(find.byTooltip('Anno precedente'));
    await tester.tap(find.byTooltip('Anno precedente'));
    await tester.pump();
    expect(find.text('2024'), findsOneWidget);
    await tester.tap(find.text('Ago'));
    expect(await result(), DateTime(2024, 8));
  });

  testWidgets('niente mesi futuri, "Questo mese" torna a oggi', (tester) async {
    final now = DateTime.now();
    final result = await open(tester, DateTime(now.year, now.month));
    final next = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right));
    expect(next.onPressed, isNull, reason: "l'anno prossimo non si sceglie");
    if (now.month < 12) {
      final dec = tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Dic'));
      expect(dec.onPressed, isNull);
    }
    await tester.tap(find.text('Questo mese'));
    expect(await result(), DateTime(now.year, now.month));
  });
}
