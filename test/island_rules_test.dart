import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_app/island/catalog.dart';
import 'package:receipt_app/island/rules.dart';

void main() {
  test('mesi come aaaamm', () {
    expect(monthKey(DateTime(2026, 11, 8, 23, 59)), 202611);
    expect(addMonths(202612, 1), 202701);
    expect(addMonths(202601, -1), 202512);
    expect(daysInMonth(202602), 28);
    expect(daysInMonth(202802), 29);
    expect(monthsBetween(202611, 202702).toList(), [202611, 202612, 202701, 202702]);
    expect(monthsBetween(202703, 202702), isEmpty);
  });

  test('i limiti cambiati fino al 5 valgono per il mese, dopo dal successivo', () {
    expect(limitsFixedAt(202611), DateTime(2026, 11, 6));
    expect(firstMonthOfLimitChange(DateTime(2026, 11, 5, 23)), 202611);
    expect(firstMonthOfLimitChange(DateTime(2026, 11, 6)), 202612);
    expect(firstMonthOfLimitChange(DateTime(2026, 12, 20)), 202701);
  });

  test('stima prudente del ritmo', () {
    expect(prudentRate(0, 30), 0);
    expect(prudentRate(3, 30), 0, reason: 'con 3 registrazioni il limite basso è sotto zero');
    expect(prudentRate(10, 30), closeTo(0.122, 0.001));
    expect(prudentRate(30, 30), closeTo(0.635, 0.001));
    expect(prudentRate(90, 90), closeTo(0.789, 0.001));
    expect(prudentRate(5, 0), 0);
  });

  test('buco tollerato: 5 giorni a 2 al giorno, 8 a 1 al giorno, 14 sotto 1 ogni 2', () {
    expect(gapLimit(2), 5);
    expect(gapLimit(1), closeTo(8.0, 0.01));
    expect(gapLimit(0.5), 14);
    expect(gapLimit(0.1), 14);
    expect(gapLimit(0.001), 14, reason: 'con λ quasi zero la formula non vale');
    expect(gapLimit(0), 14);
  });

  /// Una registrazione per ognuno dei [days] giorni.
  List<DateTime> everyDay(DateTime from, int days, {int step = 1}) => [
    for (var i = 0; i < days; i += step) DateTime(from.year, from.month, from.day + i, 12),
  ];

  group('controllo delle registrazioni', () {
    // 90 giorni prima di novembre 2026, una spesa al giorno: λ prudente 0,79,
    // buco tollerato 9,8 giorni, almeno 12 spese a novembre.
    final history = everyDay(DateTime(2026, 8, 3), 90);
    final first = history.first;

    test('chi registra ogni giorno passa', () {
      final c = checkRecording(
        month: 202611,
        dates: [...history, ...everyDay(DateTime(2026, 11, 1), 30)],
        firstRecord: first,
      );
      expect(c.rate, closeTo(0.789, 0.001));
      expect(c.gapAllowed, closeTo(9.85, 0.01));
      expect((c.days, c.records, c.minimum, c.longestGap), (30, 30, 12, 0));
      expect(c.ok, isTrue);
    });

    test('un buco più lungo del suo ritmo no', () {
      // Spese fino al 10, poi dal 21: dall'11 al 20 sono 10 giorni vuoti.
      final nov = [...everyDay(DateTime(2026, 11, 1), 10), ...everyDay(DateTime(2026, 11, 21), 10)];
      final c = checkRecording(month: 202611, dates: [...history, ...nov], firstRecord: first);
      expect(c.longestGap, 10);
      expect((c.noLongGap, c.ok), (false, false));
      // Con 9 giorni vuoti invece sì.
      final ok = checkRecording(
        month: 202611,
        dates: [...history, ...everyDay(DateTime(2026, 11, 1), 10), ...everyDay(DateTime(2026, 11, 20), 11)],
        firstRecord: first,
      );
      expect((ok.longestGap, ok.ok), (9, true));
    });

    test('troppe poche spese rispetto al solito no, anche senza buchi', () {
      // Una ogni 3 giorni: 10 spese, ne servono 12.
      final c = checkRecording(
        month: 202611,
        dates: [...history, ...everyDay(DateTime(2026, 11, 1), 30, step: 3)],
        firstRecord: first,
      );
      expect((c.records, c.minimum, c.longestGap), (10, 12, 2));
      expect((c.enough, c.ok), (false, false));
    });

    test('conta la data della spesa, non quando è stata inserita', () {
      // Le stesse date in ordine sparso (come inserite tutte la domenica).
      final nov = everyDay(DateTime(2026, 11, 1), 30).reversed;
      expect(checkRecording(month: 202611, dates: [...nov, ...history], firstRecord: first).ok, isTrue);
    });

    test('il primo mese contano solo i giorni dalla prima spesa, con buco massimo 14', () {
      final oct = [DateTime(2026, 10, 20), DateTime(2026, 10, 25), DateTime(2026, 10, 31, 20)];
      final c = checkRecording(month: 202610, dates: oct, firstRecord: oct.first);
      expect((c.rate, c.days, c.records, c.longestGap, c.gapAllowed), (0.0, 12, 3, 5, 14.0));
      expect(c.ok, isTrue);
    });

    test('nel mese in corso contano solo i giorni fino a oggi', () {
      final nov = everyDay(DateTime(2026, 11, 1), 10);
      final c = checkRecording(
        month: 202611,
        dates: [...history, ...nov],
        firstRecord: first,
        until: DateTime(2026, 11, 10, 18),
      );
      expect((c.days, c.records, c.longestGap, c.ok), (10, 10, 0, true));
      // Il 1° alle 8, senza ancora spese: un giorno vuoto, non un mese.
      final early = checkRecording(month: 202611, dates: history, firstRecord: first, until: DateTime(2026, 11, 1, 8));
      expect((early.days, early.longestGap), (1, 1));
    });

    test('un mese senza spese non vale mai', () {
      final c = checkRecording(month: 202611, dates: history, firstRecord: first);
      expect((c.records, c.longestGap, c.ok), (0, 30, false));
      expect(checkRecording(month: 202611, dates: const [], firstRecord: null).ok, isFalse);
    });

    test('con pochi dati il controllo è morbido', () {
      // Primo mese: 10 spese. Il secondo mese ne bastano 2, con buchi fino a 14 giorni.
      final oct = everyDay(DateTime(2026, 10, 1), 30, step: 3);
      final nov = [DateTime(2026, 11, 2), DateTime(2026, 11, 16), DateTime(2026, 11, 29)];
      final c = checkRecording(month: 202611, dates: [...oct, ...nov], firstRecord: oct.first);
      expect(c.rate, closeTo(10 / 31 - 2 * 3.1623 / 31, 0.001));
      expect((c.minimum, c.gapAllowed, c.longestGap), (2, 14.0, 13));
      expect(c.ok, isTrue);
    });
  });

  group('il mese', () {
    final dates = [for (var d = 1; d <= 30; d++) DateTime(2026, 11, d)];
    List<ExpenseFact> spending(Map<int, int> perCategory) => [
      // Una spesa al giorno (registrazioni a posto), importi nel primo giorno.
      for (final d in dates.skip(1)) ExpenseFact(d, 99, 100),
      for (final e in perCategory.entries) ExpenseFact(dates.first, e.key, e.value),
    ];

    test('conta il totale delle categorie con limite: una sopra può essere compensata', () {
      final r = evaluateMonth(
        month: 202611,
        limits: {1: 10000, 2: 5000},
        expenses: spending({1: 8000, 2: 7000, 3: 50000}),
        firstRecord: dates.first,
      );
      expect((r.limit, r.spent, r.withinLimits, r.recording.ok, r.eligible), (15000, 15000, true, true, true));
    });

    test('un centesimo oltre il totale no', () {
      final r = evaluateMonth(
        month: 202611,
        limits: {1: 10000, 2: 5000},
        expenses: spending({1: 8000, 2: 7001}),
        firstRecord: dates.first,
      );
      expect((r.withinLimits, r.eligible), (false, false));
    });

    test('senza limiti non si pianta', () {
      final r = evaluateMonth(month: 202611, limits: const {}, expenses: spending({1: 1}), firstRecord: dates.first);
      expect((r.hasLimits, r.eligible), (false, false));
    });

    test('le spese degli altri mesi non contano', () {
      final r = evaluateMonth(
        month: 202611,
        limits: {1: 1000},
        expenses: [
          ...spending({1: 500}),
          ExpenseFact(DateTime(2026, 10, 31, 23, 59), 1, 5000),
          ExpenseFact(DateTime(2026, 12, 1), 1, 5000),
        ],
        firstRecord: DateTime(2026, 10, 31),
      );
      expect(r.spent, 500);
    });
  });

  test('il regalo è il mese prima, tranne a gennaio', () {
    expect(giftMonth(DateTime(2026, 11, 8)), 202610);
    expect(islandStart(DateTime(2026, 11, 8)), 202610);
    expect(giftMonth(DateTime(2027, 1, 15)), isNull);
    expect(islandStart(DateTime(2027, 1, 15)), 202701);
    expect(giftMonth(DateTime(2027, 2, 1)), 202701);
    // Con spese già registrate l'isola parte dalla prima dell'anno, mai prima di gennaio.
    expect(islandStart(DateTime(2026, 11, 8), firstRecord: DateTime(2026, 3, 20)), 202603);
    expect(islandStart(DateTime(2026, 11, 8), firstRecord: DateTime(2025, 6, 1)), 202601);
    expect(islandStart(DateTime(2026, 11, 8), firstRecord: DateTime(2026, 11, 2)), 202610);
    expect(islandStart(DateTime(2027, 1, 15), firstRecord: DateTime(2026, 4, 1)), 202701);
  });

  test('posti dell\'isola e premio', () {
    expect(islandMonths(2026, 202610), [202610, 202611, 202612]);
    expect(islandMonths(2027, 202610).length, 12);
    expect(islandMonths(2025, 202610), isEmpty);
    expect(
      [
        for (final n in [1, 2, 3, 11, 12]) rewardThreshold(n),
      ],
      [1, 2, 2, 6, 7],
    );
    expect(
      [for (var y = 2026; y <= 2031; y++) centerpieceFor(y, 2026)],
      ['lighthouse', 'fountain', 'temple', 'statue', 'obelisk', 'lighthouse'],
    );
  });

  test('stagioni dell\'emisfero nord', () {
    expect(
      [for (var m = 1; m <= 12; m++) seasonOf(m).name],
      [
        'winter', 'winter', 'spring', 'spring', 'spring', 'summer', //
        'summer', 'summer', 'autumn', 'autumn', 'autumn', 'winter',
      ],
    );
  });

  test('fasi della luna sulle eclissi del 2026', () {
    // Eclissi totale di sole: 12 agosto 2026, luna nuova.
    final newMoon = moonAge(DateTime.utc(2026, 8, 12, 17, 46));
    expect(newMoon < 0.02 || newMoon > 0.98, isTrue, reason: '$newMoon');
    expect(moonIllumination(newMoon), lessThan(0.01));
    // Eclissi totale di luna: 3 marzo 2026, luna piena.
    final full = moonAge(DateTime.utc(2026, 3, 3, 11, 33));
    expect(full, closeTo(0.5, 0.02));
    expect(moonIllumination(full), greaterThan(0.99));
    // Una settimana dopo la luna nuova: quasi primo quarto, metà disco. Il
    // ciclo medio sbaglia le fasi vere fino a mezza giornata e poco più
    // (l'orbita non è un cerchio): ±0,03 del ciclo.
    final quarter = moonAge(DateTime.utc(2026, 8, 19, 17, 46));
    expect(quarter, closeTo(7 / synodicMonth, 0.03));
    expect(moonIllumination(0.25), closeTo(0.5, 1e-9));
    expect(moonIllumination(0.75), closeTo(0.5, 1e-9));
  });

  test('catalogo: chiavi uniche, mesi validi, intervalli di fioritura', () {
    expect(plantCatalog.length, 32);
    expect(plantCatalog.map((s) => s.key).toSet().length, 32);
    for (final s in plantCatalog) {
      expect([...s.bloom, ...s.fruit, s.best].every((m) => m >= 1 && m <= 12), isTrue, reason: s.key);
    }
    expect(speciesByKey('olive')!.shape, PlantShape.tree);
    expect(speciesByKey('baobab'), isNull);
    expect(monthRange({12, 1, 2}), (12, 2));
    expect(monthRange({6, 7, 8}), (6, 8));
    expect(monthRange(const {}), isNull);
    expect(monthRange({for (var m = 1; m <= 12; m++) m}), isNull);
  });
}
