import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:receipt_app/data/backup.dart';
import 'package:receipt_app/data/database.dart';
import 'package:receipt_app/island/island_service.dart';
import 'package:receipt_app/island/rules.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;

void main() {
  late DateTime now;
  late AppDatabase db;
  late Category groceries, leisure;
  late Account card;

  setUp(() async {
    now = DateTime(2026, 11, 8, 10);
    db = AppDatabase(NativeDatabase.memory(), clock: () => now);
    final cats = {for (final c in await db.allCategories()) c.name: c};
    groceries = cats['Spesa']!;
    leisure = cats['Svago']!;
    card = (await db.watchAccounts().first).first;
  });
  tearDown(() => db.close());

  Future<void> setLimit(Category c, int? cents) =>
      db.saveCategory(CategoriesCompanion(id: Value(c.id), monthlyLimitCents: Value(cents)));

  Future<void> spend(Category c, int cents, DateTime date) =>
      db.saveExpense(ExpensesCompanion.insert(amountCents: cents, date: date, categoryId: c.id, accountId: card.id));

  /// Una spesa da [cents] al giorno, dal [from] per [days] giorni.
  Future<void> daily(Category c, int cents, DateTime from, int days) async {
    for (var i = 0; i < days; i++) {
      await spend(c, cents, DateTime(from.year, from.month, from.day + i, 12));
    }
  }

  test('alla prima apertura di novembre: isola da ottobre, ottobre in regalo', () async {
    final s = await IslandService.load(db);
    expect((s.start, s.gift, s.currentMonth), (202610, 202610, 202611));
    expect(s.pending, [202610]);
    expect(s.years.single.months, [202610, 202611, 202612]);
    expect(s.years.single.needed, 2);
    expect(s.hasLimits, isFalse);
    // La seconda volta non cambia niente.
    now = DateTime(2026, 11, 20);
    expect((await IslandService.load(db)).gift, 202610);
  });

  test('chi ha già spese quest\'anno ritrova i mesi passati, valutati con i limiti del primo avvio', () async {
    await setLimit(groceries, 30000);
    // Da marzo a ottobre una spesa al giorno: 5 € (150 € al mese), tranne
    // giugno a 15 € (450 €, oltre il limite) e agosto registrato solo fino al 10.
    for (var d = DateTime(2026, 3, 1); d.isBefore(DateTime(2026, 11, 1)); d = DateTime(d.year, d.month, d.day + 1)) {
      if (d.month == 8 && d.day > 10) continue;
      await spend(groceries, d.month == 6 ? 1500 : 500, DateTime(d.year, d.month, d.day, 12));
    }
    final s = await IslandService.load(db);
    expect((s.start, s.gift), (202603, 202610));
    expect(s.years.single.months.first, 202603);
    expect((s.years.single.slots, s.years.single.needed), (10, 6));
    expect(s.pending, [202603, 202604, 202605, 202607, 202609, 202610]);
    expect(s.results[202606]!.withinLimits, isFalse);
    expect((s.results[202608]!.withinLimits, s.results[202608]!.recording.ok), (true, false));
    // I limiti dei mesi passati sono quelli del primo avvio, e restano quelli.
    now = DateTime(2026, 11, 20);
    await setLimit(groceries, 10000);
    final snaps = await db.limitSnapshotsByMonth();
    expect([for (final m in monthsBetween(202603, 202611)) snaps[m]], everyElement({groceries.id: 30000}));
  });

  test('le spese degli anni passati non fanno isole: si parte da gennaio', () async {
    await spend(groceries, 500, DateTime(2025, 6, 1));
    final s = await IslandService.load(db);
    expect(s.start, 202601);
    expect(s.years.map((y) => y.year), [2026]);
  });

  test('a gennaio niente regalo: isola intera da 12', () async {
    now = DateTime(2027, 1, 15);
    final s = await IslandService.load(db);
    expect((s.start, s.gift), (202701, null));
    expect(s.pending, isEmpty);
    expect(s.years.single.slots, 12);
  });

  test('i limiti che contano sono quelli della fine del 5', () async {
    await setLimit(groceries, 10000);
    await IslandService.load(db); // prima apertura l'8 novembre
    // Cambiato il 20: per novembre resta 100 €.
    now = DateTime(2026, 11, 20);
    await setLimit(groceries, 30000);
    // Cambiato il 3 dicembre: vale già per dicembre.
    now = DateTime(2026, 12, 3);
    await setLimit(groceries, 5000);
    now = DateTime(2026, 12, 7);
    await IslandService.load(db);
    expect(await db.limitSnapshotsByMonth(), {
      202610: {groceries.id: 10000},
      202611: {groceries.id: 10000},
      202612: {groceries.id: 5000},
    });
  });

  test('senza aprire l\'app per un mese, la copia si fa prima della modifica', () async {
    await setLimit(groceries, 10000);
    await IslandService.load(db);
    // Nessuna apertura dal 9 novembre al 10 gennaio, poi un limite cambiato.
    now = DateTime(2027, 1, 10);
    await setLimit(groceries, 99900);
    final snaps = await db.limitSnapshotsByMonth();
    expect(
      [
        for (final m in [202612, 202701]) snaps[m],
      ],
      [
        {groceries.id: 10000},
        {groceries.id: 10000},
      ],
    );
    // Anche eliminare una categoria con limite è un cambio di limiti: il
    // limite messo il 3 febbraio vale per febbraio anche se il 9 sparisce.
    now = DateTime(2027, 2, 3);
    await setLimit(leisure, 2000);
    now = DateTime(2027, 2, 9);
    await db.deleteCategory(leisure.id);
    expect((await db.limitSnapshotsByMonth())[202702], {groceries.id: 99900, leisure.id: 2000});
  });

  test('novembre nei limiti e registrato bene si pianta a dicembre; il posto si sceglie', () async {
    await setLimit(groceries, 30000);
    await daily(groceries, 500, DateTime(2026, 10, 1), 30);
    final island = IslandService(db);
    await island.init();
    await daily(groceries, 900, DateTime(2026, 11, 1), 30); // 270 € su 300
    now = DateTime(2026, 12, 2);
    await island.refresh();
    var s = island.state!;
    expect(s.pending, [202610, 202611]);
    expect((s.results[202611]!.spent, s.results[202611]!.limit), (27000, 30000));

    await island.plant(202610, 'olive', 0);
    await expectLater(island.plant(202611, 'oak', 0), throwsA(isA<PlantingException>()), reason: 'posto occupato');
    await expectLater(island.plant(202612, 'oak', 1), throwsA(isA<PlantingException>()), reason: 'mese in corso');
    await island.plant(202611, 'oak', 2);
    s = island.state!;
    expect(s.pending, isEmpty);
    expect(s.years.single.bySlot.map((k, v) => MapEntry(k, (v.month, v.plant, v.gift))), {
      0: (202610, 'olive', true),
      2: (202611, 'oak', false),
    });
    expect(s.years.single.freeSlots, [1]);
    await expectLater(island.plant(202611, 'fig', 1), throwsA(isA<PlantingException>()), reason: 'già piantato');
    island.dispose();
  });

  test('oltre i limiti, poche registrazioni o senza limiti non si pianta', () async {
    await daily(groceries, 500, DateTime(2026, 10, 1), 30);
    await IslandService.load(db);
    await daily(groceries, 1100, DateTime(2026, 11, 1), 30); // 330 €
    now = DateTime(2026, 12, 2);
    var s = await IslandService.load(db);
    expect(s.results[202611]!.hasLimits, isFalse);
    expect(s.pending, [202610]);

    // Il limite messo adesso non vale per novembre, già fissato.
    await setLimit(groceries, 30000);
    s = await IslandService.load(db);
    expect(s.results[202611]!.hasLimits, isFalse);
    expect(s.current.limit, 30000, reason: 'dicembre non è ancora fissato');

    // Gennaio: 330 € su 300 → oltre. Febbraio: nei limiti ma registrato solo il primo giorno.
    await daily(groceries, 1100, DateTime(2027, 1, 1), 30);
    await spend(groceries, 5000, DateTime(2027, 2, 1));
    now = DateTime(2027, 3, 1);
    s = await IslandService.load(db);
    expect(s.results[202701]!.withinLimits, isFalse);
    expect((s.results[202702]!.withinLimits, s.results[202702]!.recording.ok), (true, false));
    expect(s.pending, [202610]);
  });

  test('premio al centro a fine anno con più della metà dei posti', () async {
    final island = IslandService(db);
    await island.init();
    await island.plant(202610, 'olive', 1);
    expect(island.state!.years.single.rewardEarned, isFalse);
    // 1 pianta su 3: a gennaio niente premio. Con 2 sì.
    now = DateTime(2027, 1, 3);
    await island.refresh();
    final first = island.state!.years.first;
    expect((first.over, first.planted, first.needed, first.rewardEarned), (true, 1, 2, false));
    expect(island.state!.years.map((y) => (y.year, y.centerpiece)), [(2026, 'lighthouse'), (2027, 'fountain')]);
    await db.addPlanting(PlantingsCompanion.insert(month: const Value(202612), plant: 'fir', slot: 0));
    await island.refresh();
    expect(island.state!.years.first.rewardEarned, isTrue);
    island.dispose();
  });

  test('piante e copie dei limiti passano dal backup', () async {
    final tmp = await Directory.systemTemp.createTemp('island_backup');
    await setLimit(groceries, 12300);
    final island = IslandService(db);
    await island.init();
    await island.plant(202610, 'lavender', 2);
    island.dispose();
    final zip = await exportBackupTo(db, tmp.path);

    final other = AppDatabase(NativeDatabase.memory(), clock: () => now);
    final preview = await openBackup(zip, tmpDir: tmp.path, currentSchema: other.schemaVersion);
    await restore(other, preview, receiptsDir: p.join(tmp.path, 'receipts'));
    await preview.dispose();
    final s = await IslandService.load(other);
    expect((s.start, s.gift), (202610, 202610));
    expect(s.pending, isEmpty);
    expect(s.years.single.bySlot[2]!.plant, 'lavender');
    expect(await other.limitSnapshotsByMonth(), await db.limitSnapshotsByMonth());
    await other.close();
    await tmp.delete(recursive: true);
  });

  test('un database della 0.3.5 (schema 2) riceve le tabelle dell\'isola', () async {
    final tmp = await Directory.systemTemp.createTemp('island_migration');
    final file = File(p.join(tmp.path, 'spese.sqlite'));
    // Le tabelle di prima, prese da un database nuovo meno quelle dell'isola.
    final fresh = await db
        .customSelect("SELECT sql FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'")
        .get();
    final raw = sqlite3.open(file.path);
    for (final row in fresh) {
      final sql = row.read<String>('sql');
      if (!sql.contains('plantings') && !sql.contains('limit_snapshots')) raw.execute(sql);
    }
    raw.execute("INSERT INTO settings (key, value) VALUES ('receipt_lang', 'it')");
    raw.execute('PRAGMA user_version = 2');
    raw.close();

    final migrated = AppDatabase(NativeDatabase(file), clock: () => now);
    expect(await migrated.setting('receipt_lang'), 'it');
    expect(await migrated.allPlantings(), isEmpty);
    expect((await IslandService.load(migrated)).pending, [202610]);
    await migrated.close();
    await tmp.delete(recursive: true);
  });
}
