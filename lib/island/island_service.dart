import 'dart:async';

import 'package:drift/drift.dart' show TableUpdateQuery, Value;
import 'package:flutter/foundation.dart';

import '../data/database.dart';
import 'rules.dart';

/// L'isola di un anno: i suoi posti (uno per mese) e cosa c'è piantato.
class IslandYear {
  final int year;

  /// I mesi che hanno un posto, in ordine: il posto i è "del" mese i solo
  /// come numero di posti, la pianta di un mese va dove si sceglie.
  final List<int> months;
  final Map<int, Planting> bySlot;

  /// L'anno è finito: si sa se al centro spunta il premio.
  final bool over;
  final String centerpiece;

  const IslandYear({
    required this.year,
    required this.months,
    required this.bySlot,
    required this.over,
    required this.centerpiece,
  });

  int get slots => months.length;
  int get planted => bySlot.length;
  int get needed => rewardThreshold(slots);
  bool get rewardEarned => over && planted >= needed;
  bool get complete => planted == slots;
  List<int> get freeSlots => [
    for (var i = 0; i < slots; i++)
      if (!bySlot.containsKey(i)) i,
  ];
  Planting? plantingOf(int month) => bySlot.values.where((p) => p.month == month).firstOrNull;
}

/// Tutto quello che serve allo schermo dell'isola, calcolato in una volta.
class IslandState {
  /// Primo mese della prima isola, e il mese regalato (se c'è).
  final int start;
  final int? gift;
  final int currentMonth;

  /// Dalla più vecchia all'anno in corso.
  final List<IslandYear> years;

  /// I mesi chiusi non ancora piantati, con il loro risultato.
  final Map<int, MonthResult> results;

  /// I mesi da piantare, dal più vecchio: il regalo e quelli superati.
  final List<int> pending;

  /// Il mese in corso, finora.
  final MonthResult current;
  final bool hasLimits;

  const IslandState({
    required this.start,
    required this.gift,
    required this.currentMonth,
    required this.years,
    required this.results,
    required this.pending,
    required this.current,
    required this.hasLimits,
  });

  IslandYear yearOf(int month) => years.firstWhere((y) => y.year == month ~/ 100);
}

/// Perché non si può piantare.
class PlantingException implements Exception {
  final String reason;
  const PlantingException(this.reason);
  @override
  String toString() => 'PlantingException: $reason';
}

/// L'isola sopra il database: la crea alla prima apertura (col regalo), tiene
/// le copie dei limiti, valuta i mesi e pianta. Si ricalcola da sola quando
/// cambiano spese, categorie o piante.
class IslandService extends ChangeNotifier {
  final AppDatabase db;
  IslandService(this.db);

  IslandState? _state;
  IslandState? get state => _state;
  int get pendingCount => _state?.pending.length ?? 0;

  StreamSubscription<void>? _changes;
  Timer? _debounce;
  bool _disposed = false;

  /// Da chiamare dopo lo sblocco (prima il database non si apre).
  Future<void> init() async {
    await refresh();
    _changes ??= db
        .tableUpdates(
          TableUpdateQuery.onAllTables([db.expenses, db.categories, db.plantings, db.limitSnapshots, db.settings]),
        )
        .listen((_) {
          _debounce?.cancel();
          _debounce = Timer(const Duration(milliseconds: 300), () => refresh().ignore());
        });
  }

  /// Ricalcola lo stato. Alla prima volta (o dopo un ripristino da un backup
  /// senza isola) decide il primo mese e il regalo.
  Future<void> refresh() async {
    final s = await load(db);
    if (_disposed) return;
    _state = s;
    notifyListeners();
  }

  /// Lo stato dell'isola in [db], adesso ([AppDatabase.clock]).
  static Future<IslandState> load(AppDatabase db) async {
    final now = db.clock();
    final current = monthKey(now);
    var start = int.tryParse(await db.setting(islandStartSetting) ?? '');
    if (start == null) {
      start = islandStart(now);
      final gift = giftMonth(now);
      await db.transaction(() async {
        await db.setSetting(islandStartSetting, '$start');
        if (gift != null) await db.setSetting(islandGiftSetting, '$gift');
      });
    }
    final gift = int.tryParse(await db.setting(islandGiftSetting) ?? '');
    await db.snapshotLimits();

    final snapshots = await db.limitSnapshotsByMonth();
    final currentLimits = await db.currentLimits();
    final plantings = await db.allPlantings();
    final planted = {for (final p in plantings) p.month};
    final firstRecord = await db.firstExpenseDate();
    final facts = await db.expenseFactsSince(monthStart(start).subtract(const Duration(days: historyDays + 1)));

    MonthResult evaluate(int m) => evaluateMonth(
      month: m,
      limits: snapshots[m] ?? currentLimits,
      expenses: facts,
      firstRecord: firstRecord,
      until: m == current ? now : null,
    );

    final results = <int, MonthResult>{};
    final pending = <int>[];
    for (final m in monthsBetween(start, addMonths(current, -1))) {
      if (planted.contains(m)) continue;
      final r = evaluate(m);
      results[m] = r;
      if (m == gift || r.eligible) pending.add(m);
    }

    final firstYear = start ~/ 100;
    final years = [
      for (var y = firstYear; y <= now.year; y++)
        IslandYear(
          year: y,
          months: islandMonths(y, start),
          bySlot: {
            for (final p in plantings)
              if (p.month ~/ 100 == y) p.slot: p,
          },
          over: y < now.year,
          centerpiece: centerpieceFor(y, firstYear),
        ),
    ];
    return IslandState(
      start: start,
      gift: gift,
      currentMonth: current,
      years: years,
      results: results,
      pending: pending,
      current: evaluate(current),
      hasLimits: currentLimits.isNotEmpty,
    );
  }

  /// Mette [plant] al posto [slot] dell'isola di [month]. Il mese deve essere
  /// da piantare (regalo o superato) e il posto libero.
  Future<void> plant(int month, String plant, int slot) async {
    final s = await load(db);
    if (!s.pending.contains(month)) throw const PlantingException('month not plantable');
    final island = s.yearOf(month);
    if (slot < 0 || slot >= island.slots || island.bySlot.containsKey(slot)) {
      throw const PlantingException('slot not free');
    }
    await db.addPlanting(
      PlantingsCompanion.insert(
        month: Value(month),
        plant: plant,
        slot: slot,
        gift: Value(month == s.gift),
        plantedAt: Value(db.clock()),
      ),
    );
    await refresh();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _changes?.cancel();
    super.dispose();
  }
}
