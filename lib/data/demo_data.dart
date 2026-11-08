import 'package:drift/drift.dart';

import 'database.dart';

/// Visibile solo nelle build fatte con --dart-define=DEMO=true.
const demoEnabled = bool.fromEnvironment('DEMO');

/// Riempie [month] e il mese prima con spese inventate e mette qualche
/// limite, per vedere riepilogo e avvisi senza dati veri.
Future<void> loadDemoData(AppDatabase db, DateTime month) async {
  final cats = {for (final c in await db.allCategories()) c.name: c};
  final accounts = await db.watchAccounts().first;
  final card = accounts.firstWhere((a) => a.kind == AccountKind.card);
  final cash = accounts.firstWhere((a) => a.kind == AccountKind.cash);

  final limits = {'Spesa': 30000, 'Ristoranti e bar': 15000, 'Svago': 10000, 'Trasporti': 12000};
  for (final e in limits.entries) {
    final c = cats[e.key];
    if (c != null) await db.saveCategory(CategoriesCompanion(id: Value(c.id), monthlyLimitCents: Value(e.value)));
  }

  // (giorno, categoria, esercente, euro, contanti?)
  const current = [
    (1, 'Spesa', 'Esselunga', 46.80, false),
    (2, 'Ristoranti e bar', 'Bar Centrale', 3.20, true),
    (3, 'Trasporti', 'Eni Station', 55.00, false),
    (4, 'Svago', 'Cinema Odeon', 18.00, false),
    (6, 'Ristoranti e bar', 'Trattoria da Pino', 57.46, true),
    (7, 'Spesa', 'Lidl', 32.15, false),
    (9, 'Casa e bollette', 'Enel Energia', 68.40, false),
    (10, 'Svago', 'Libreria Feltrinelli', 24.90, false),
    (11, 'Salute', 'Farmacia Centrale', 12.60, true),
    (12, 'Ristoranti e bar', 'Pizzeria Bella Napoli', 28.00, false),
    (14, 'Spesa', 'Conad', 58.30, false),
    (15, 'Shopping', 'Decathlon', 39.99, false),
    (17, 'Svago', 'Spotify', 10.99, false),
    (18, 'Ristoranti e bar', 'Starbucks', 6.80, false),
    (19, 'Trasporti', 'Trenitalia', 19.90, false),
    (21, 'Spesa', 'Esselunga', 41.25, false),
    (22, 'Svago', 'Teatro Massimo', 35.00, false),
    (24, 'Ristoranti e bar', 'Sushi Ko', 32.50, false),
    (25, 'Casa e bollette', 'Iliad', 9.99, false),
    (26, 'Svago', 'Bowling Planet', 22.00, true),
    (28, 'Spesa', 'Mercato rionale', 18.40, true),
    (29, 'Altro', 'Regalo compleanno', 25.00, true),
  ];
  const previous = [
    (2, 'Spesa', 'Esselunga', 52.10, false),
    (5, 'Ristoranti e bar', 'Trattoria da Pino', 44.00, true),
    (8, 'Trasporti', 'Q8', 60.00, false),
    (12, 'Svago', 'Cinema Odeon', 16.00, false),
    (15, 'Casa e bollette', 'Enel Energia', 71.30, false),
    (18, 'Spesa', 'Lidl', 38.70, false),
    (22, 'Ristoranti e bar', 'Bar Centrale', 12.40, true),
    (26, 'Salute', 'Farmacia Centrale', 23.80, false),
  ];

  Future<void> add(DateTime m, List<(int, String, String, double, bool)> rows) async {
    for (final (day, cat, merchant, euros, isCash) in rows) {
      final c = cats[cat];
      if (c == null) continue;
      await db.saveExpense(ExpensesCompanion.insert(
        amountCents: (euros * 100).round(),
        date: DateTime(m.year, m.month, day, 12),
        merchant: Value(merchant),
        categoryId: c.id,
        accountId: isCash ? cash.id : card.id,
      ));
    }
  }

  await add(month, current);
  await add(DateTime(month.year, month.month - 1), previous);
}

/// Un arcipelago di prova: il 2025 pieno (col premio al centro) e il 2026
/// fino a settembre, nei posti ancora liberi. Le spese di quei mesi non ci
/// sono: le piante servono solo a vedere le isole.
Future<void> loadDemoIsland(AppDatabase db) async {
  await db.setSetting(islandStartSetting, '202501');
  const y2025 = [
    'olive', 'apple', 'cherry', 'lavender', 'cypress', 'sunflower', //
    'lemon', 'fir', 'hydrangea', 'datePalm', 'oak', 'jasmine',
  ];
  const y2026 = ['maple', 'almond', 'rose', 'cactus', 'orange', 'stonePine', 'tulip', 'bougainvillea', 'willow'];
  final existing = await db.allPlantings();
  final used = {for (final p in existing) (p.month ~/ 100, p.slot)};
  final months = {for (final p in existing) p.month};
  await db.batch((b) {
    for (final (year, plants) in [(2025, y2025), (2026, y2026)]) {
      var slot = 0;
      for (var i = 0; i < plants.length; i++) {
        final month = year * 100 + i + 1;
        if (months.contains(month)) continue;
        while (used.contains((year, slot))) {
          slot++;
        }
        used.add((year, slot));
        b.insert(db.plantings, PlantingsCompanion.insert(month: Value(month), plant: plants[i], slot: slot));
      }
    }
  });
}
