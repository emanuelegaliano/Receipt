import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/common.dart' show CommonDatabase;

import '../island/rules.dart';
import '../security/vault.dart';

part 'database.g.dart';

enum AccountKind { card, cash, other }

/// Da dove arrivano i soldi: carta, contanti, ...
class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get kind => intEnum<AccountKind>()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get icon => text()(); // chiave in CategoryIcons
  IntColumn get color => integer()(); // ARGB
  /// Parole chiave separate da virgola, usate per indovinare la categoria
  /// di un esercente mai visto (es. "farmacia,pharmacy").
  TextColumn get keywords => text().withDefault(const Constant(''))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  /// Quanto si vuole spendere al massimo in un mese; null = nessun limite.
  IntColumn get monthlyLimitCents => integer().nullable()();
}

class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get amountCents => integer()();
  DateTimeColumn get date => dateTime()();
  TextColumn get merchant => text().withDefault(const Constant(''))();
  IntColumn get categoryId => integer().references(Categories, #id)();
  IntColumn get accountId => integer().references(Accounts, #id)();
  TextColumn get note => text().withDefault(const Constant(''))();
  /// Foto dello scontrino salvata nella cartella dell'app, se presente.
  TextColumn get receiptPath => text().nullable()();
  TextColumn get ocrText => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Esercente normalizzato -> categoria, imparato da ciò che salvi.
class MerchantRules extends Table {
  TextColumn get merchantKey => text()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  IntColumn get hits => integer().withDefault(const Constant(1))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {merchantKey};
}

/// Una pianta sull'isola (vedi docs/ISLAND.md): al massimo una per mese, nel
/// posto [slot] dell'isola del suo anno.
class Plantings extends Table {
  /// Mese come aaaamm, es. 202610: un numero non si sposta col fuso orario.
  IntColumn get month => integer()();
  /// Chiave nel catalogo (lib/island/catalog.dart), es. "olive".
  TextColumn get plant => text()();
  IntColumn get slot => integer()();
  /// La pianta regalata alla prima apertura dell'isola.
  BoolColumn get gift => boolean().withDefault(const Constant(false))();
  DateTimeColumn get plantedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {month};
}

/// I limiti che contano per l'isola in un mese: quelli alla fine del giorno 5.
class LimitSnapshots extends Table {
  /// aaaamm, come in [Plantings].
  IntColumn get month => integer()();
  /// JSON {"id categoria": centesimi}; {} se quel mese non c'erano limiti.
  TextColumn get limits => text()();

  @override
  Set<Column> get primaryKey => {month};
}

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Spesa con categoria e conto già uniti, per le liste.
class ExpenseView {
  final Expense expense;
  final Category category;
  final Account account;
  const ExpenseView(this.expense, this.category, this.account);
}

@DriftDatabase(tables: [Accounts, Categories, Expenses, MerchantRules, Settings, Plantings, LimitSnapshots])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor, {this.clock = DateTime.now});

  /// L'ora di adesso; nei test una data fissa.
  final DateTime Function() clock;

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seed();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.addColumn(categories, categories.monthlyLimitCents);
          if (from < 3) {
            await m.createTable(plantings);
            await m.createTable(limitSnapshots);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<void> _seed() async {
    await batch((b) {
      b.insertAll(accounts, [
        AccountsCompanion.insert(name: 'Carta', kind: AccountKind.card, sortOrder: const Value(0)),
        AccountsCompanion.insert(name: 'Contanti', kind: AccountKind.cash, sortOrder: const Value(1)),
      ]);
      var i = 0;
      for (final c in defaultCategories) {
        b.insert(
          categories,
          CategoriesCompanion.insert(
            name: c.name,
            icon: c.icon,
            color: c.color,
            keywords: Value(c.keywords),
            sortOrder: Value(i++),
          ),
        );
      }
    });
  }

  // --- Conti e categorie ---------------------------------------------------

  Stream<List<Account>> watchAccounts() =>
      (select(accounts)..where((a) => a.archived.equals(false))..orderBy([(a) => OrderingTerm(expression: a.sortOrder)]))
          .watch();

  Stream<List<Category>> watchCategories() => (select(categories)
        ..where((c) => c.archived.equals(false))
        ..orderBy([(c) => OrderingTerm(expression: c.sortOrder)]))
      .watch();

  Future<List<Category>> allCategories() => (select(categories)
        ..where((c) => c.archived.equals(false))
        ..orderBy([(c) => OrderingTerm(expression: c.sortOrder)]))
      .get();

  Future<int> saveCategory(CategoriesCompanion c) => transaction(() async {
        // Prima di toccare un limite, i mesi dell'isola già fissati se lo
        // tengono com'era.
        await snapshotLimits();
        if (c.id.present) {
          await (update(categories)..where((t) => t.id.equals(c.id.value))).write(c);
          return c.id.value;
        }
        final maxOrder = await (selectOnly(categories)..addColumns([categories.sortOrder.max()]))
            .map((r) => r.read(categories.sortOrder.max()))
            .getSingleOrNull();
        return into(categories).insert(c.copyWith(sortOrder: Value((maxOrder ?? 0) + 1)));
      });

  Future<int> categoryExpenseCount(int id) async {
    final n = expenses.id.count();
    final q = selectOnly(expenses)
      ..addColumns([n])
      ..where(expenses.categoryId.equals(id));
    return await q.map((r) => r.read(n)).getSingle() ?? 0;
  }

  /// Elimina una categoria. Le sue spese (e gli esercenti imparati) passano
  /// a [moveTo]; senza [moveTo] la categoria deve essere vuota.
  Future<void> deleteCategory(int id, {int? moveTo}) => transaction(() async {
        await snapshotLimits();
        if (moveTo != null) {
          await (update(expenses)..where((e) => e.categoryId.equals(id)))
              .write(ExpensesCompanion(categoryId: Value(moveTo)));
          await (update(merchantRules)..where((r) => r.categoryId.equals(id)))
              .write(MerchantRulesCompanion(categoryId: Value(moveTo)));
        } else {
          await (delete(merchantRules)..where((r) => r.categoryId.equals(id))).go();
        }
        await (delete(categories)..where((c) => c.id.equals(id))).go();
        // Le sue spese ora sono in un'altra categoria: se il suo limite
        // restasse nelle copie, l'isola conterebbe il limite senza le spese.
        // Via limite e spese insieme, anche per il mese in corso.
        for (final s in await select(limitSnapshots).get()) {
          final limits = jsonDecode(s.limits) as Map<String, dynamic>;
          if (limits.remove('$id') == null) continue;
          await (update(limitSnapshots)..where((t) => t.month.equals(s.month)))
              .write(LimitSnapshotsCompanion(limits: Value(jsonEncode(limits))));
        }
      });

  Future<int> saveAccount(AccountsCompanion a) async {
    if (a.id.present) {
      await (update(accounts)..where((t) => t.id.equals(a.id.value))).write(a);
      return a.id.value;
    }
    return into(accounts).insert(a);
  }

  // --- Spese ---------------------------------------------------------------

  Stream<List<ExpenseView>> watchExpenses(DateTime from, DateTime to) {
    final q = select(expenses).join([
      innerJoin(categories, categories.id.equalsExp(expenses.categoryId)),
      innerJoin(accounts, accounts.id.equalsExp(expenses.accountId)),
    ])
      ..where(expenses.date.isBiggerOrEqualValue(from) & expenses.date.isSmallerThanValue(to))
      ..orderBy([OrderingTerm.desc(expenses.date), OrderingTerm.desc(expenses.id)]);
    return q.watch().map((rows) => [
          for (final r in rows) ExpenseView(r.readTable(expenses), r.readTable(categories), r.readTable(accounts)),
        ]);
  }

  Future<Expense?> expenseById(int id) => (select(expenses)..where((e) => e.id.equals(id))).getSingleOrNull();

  Future<int> saveExpense(ExpensesCompanion e) async {
    return transaction(() async {
      final int id;
      if (e.id.present) {
        await (update(expenses)..where((t) => t.id.equals(e.id.value))).write(e);
        id = e.id.value;
      } else {
        id = await into(expenses).insert(e);
      }
      return id;
    });
  }

  /// Speso in una categoria nel mese di [month], esclusa la spesa [exceptId].
  Future<int> categorySpent(int categoryId, DateTime month, {int? exceptId}) async {
    final total = expenses.amountCents.sum();
    final q = selectOnly(expenses)
      ..addColumns([total])
      ..where(expenses.categoryId.equals(categoryId) &
          expenses.date.isBiggerOrEqualValue(DateTime(month.year, month.month)) &
          expenses.date.isSmallerThanValue(DateTime(month.year, month.month + 1)) &
          (exceptId == null ? const Constant(true) : expenses.id.equals(exceptId).not()));
    return await q.map((r) => r.read(total)).getSingle() ?? 0;
  }

  Future<void> deleteExpense(int id) => (delete(expenses)..where((e) => e.id.equals(id))).go();

  Future<Set<String>> receiptPaths() async {
    final q = selectOnly(expenses)
      ..addColumns([expenses.receiptPath])
      ..where(expenses.receiptPath.isNotNull());
    return (await q.map((r) => r.read(expenses.receiptPath)!).get()).toSet();
  }

  /// Reinserisce una spesa appena eliminata (per "Annulla").
  Future<void> restoreExpense(Expense e) => into(expenses).insert(e);

  /// Ultimi esercenti usati, per il completamento automatico.
  Future<List<String>> recentMerchants({int limit = 200}) async {
    final q = selectOnly(expenses, distinct: true)
      ..addColumns([expenses.merchant])
      ..where(expenses.merchant.equals('').not())
      ..orderBy([OrderingTerm.desc(expenses.date)])
      ..limit(limit);
    return q.map((r) => r.read(expenses.merchant)!).get();
  }

  // --- Regole esercente -> categoria ---------------------------------------

  Future<Map<String, int>> loadMerchantRules() async {
    final rows = await select(merchantRules).get();
    return {for (final r in rows) r.merchantKey: r.categoryId};
  }

  Future<void> learnMerchant(String merchantKey, int categoryId) async {
    if (merchantKey.isEmpty) return;
    final existing =
        await (select(merchantRules)..where((r) => r.merchantKey.equals(merchantKey))).getSingleOrNull();
    if (existing == null) {
      await into(merchantRules).insert(MerchantRulesCompanion.insert(merchantKey: merchantKey, categoryId: categoryId));
    } else {
      await (update(merchantRules)..where((r) => r.merchantKey.equals(merchantKey))).write(MerchantRulesCompanion(
        categoryId: Value(categoryId),
        hits: Value(existing.categoryId == categoryId ? existing.hits + 1 : 1),
        updatedAt: Value(DateTime.now()),
      ));
    }
  }

  // --- Isola (docs/ISLAND.md) ---------------------------------------------

  /// I limiti di adesso: id categoria → centesimi.
  Future<Map<int, int>> currentLimits() async {
    final rows = await (select(categories)
          ..where((c) => c.archived.equals(false) & c.monthlyLimitCents.isNotNull()))
        .get();
    return {for (final c in rows) c.id: c.monthlyLimitCents!};
  }

  /// Copia i limiti di ogni mese dell'isola che ha passato il giorno 5 e non
  /// ne ha ancora una copia. I limiti cambiano solo da qui (saveCategory,
  /// deleteCategory, che la chiamano prima di scrivere): così la copia di un
  /// mese è sempre quella della fine del 5, anche se l'app quel giorno non
  /// era aperta.
  Future<void> snapshotLimits() async {
    final start = int.tryParse(await setting(islandStartSetting) ?? '');
    if (start == null) return;
    final now = clock();
    final have = {for (final s in await select(limitSnapshots).get()) s.month};
    final missing = [
      for (final m in monthsBetween(start, monthKey(now)))
        if (!have.contains(m) && !now.isBefore(limitsFixedAt(m))) m,
    ];
    if (missing.isEmpty) return;
    final limits = jsonEncode({for (final e in (await currentLimits()).entries) '${e.key}': e.value});
    await batch((b) {
      for (final m in missing) {
        b.insert(limitSnapshots, LimitSnapshotsCompanion.insert(month: Value(m), limits: limits),
            mode: InsertMode.insertOrIgnore);
      }
    });
  }

  /// Le copie dei limiti, per mese.
  Future<Map<int, Map<int, int>>> limitSnapshotsByMonth() async => {
        for (final s in await select(limitSnapshots).get())
          s.month: {
            for (final e in (jsonDecode(s.limits) as Map<String, dynamic>).entries)
              int.parse(e.key): (e.value as num).toInt(),
          },
      };

  /// Le spese da [from] in poi, ridotte a data, categoria e importo, in ordine di data.
  Future<List<ExpenseFact>> expenseFactsSince(DateTime from) async {
    final q = selectOnly(expenses)
      ..addColumns([expenses.date, expenses.categoryId, expenses.amountCents])
      ..where(expenses.date.isBiggerOrEqualValue(from))
      ..orderBy([OrderingTerm(expression: expenses.date)]);
    return q
        .map((r) => ExpenseFact(r.read(expenses.date)!, r.read(expenses.categoryId)!, r.read(expenses.amountCents)!))
        .get();
  }

  /// La data della prima spesa registrata, null se non ce ne sono.
  Future<DateTime?> firstExpenseDate() async {
    final first = expenses.date.min();
    return (selectOnly(expenses)..addColumns([first])).map((r) => r.read(first)).getSingle();
  }

  Future<List<Planting>> allPlantings() =>
      (select(plantings)..orderBy([(p) => OrderingTerm(expression: p.month)])).get();

  Future<void> addPlanting(PlantingsCompanion p) => into(plantings).insert(p);

  // --- Impostazioni --------------------------------------------------------

  Future<String?> setting(String key) async =>
      (await (select(settings)..where((s) => s.key.equals(key))).getSingleOrNull())?.value;

  Future<void> setSetting(String key, String value) =>
      into(settings).insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));
}

/// Primo mese della prima isola (aaaamm) e mese regalato, se c'è.
const islandStartSetting = 'island_start';
const islandGiftSetting = 'island_gift';

/// Il database dell'app (documenti/spese.sqlite), cifrato con la chiave
/// dei dati. Si apre solo quando [key] è pronta, cioè dopo lo sblocco: le
/// query fatte prima aspettano.
///
/// Un database ancora in chiaro (0.3.4 e prima) viene cifrato qui, la prima
/// volta. Con [keyIsNew] (chiave appena creata alla prima configurazione) un
/// database che la chiave non apre viene spostato da parte invece di
/// bloccare l'app.
QueryExecutor openEncryptedDatabase(Future<DataKey> key, {required bool Function() keyIsNew}) =>
    DatabaseConnection.delayed(Future(() async {
      final passphrase = (await key).databasePassphrase;
      final file = File(p.join((await getApplicationDocumentsDirectory()).path, 'spese.sqlite'));
      final tmp = (await getTemporaryDirectory()).path;
      if (!await encryptDatabaseInPlace(file, passphrase, tempDirectory: tmp) && keyIsNew()) {
        await moveAsideIfUnreadable(file, passphrase);
      }
      return driftDatabase(name: 'spese', native: DriftNativeOptions(setup: _keySetup(passphrase)));
    }));

/// Fuori da [openEncryptedDatabase] perché la funzione passa all'isolate del
/// database: deve portarsi dietro solo la passphrase.
void Function(CommonDatabase) _keySetup(String passphrase) => (db) => db.execute(pragmaKey(passphrase));

class DefaultCategory {
  final String name;
  final String icon;
  final int color;
  final String keywords;
  const DefaultCategory(this.name, this.icon, this.color, this.keywords);
}

/// Categorie iniziali. Le parole chiave coprono scontrini italiani e inglesi.
const defaultCategories = [
  DefaultCategory('Spesa', 'cart', 0xFF2E7D32,
      'supermercato,supermarket,market,alimentari,conad,coop,esselunga,lidl,eurospin,carrefour,despar,'
      'interspar,penny,aldi,md,todis,famila,pam,simply,tigre,crai,sigma,decò,iper,ipercoop,bennet,'
      'grocery,mart,minimarket,hypermarket,tesco,aeon,giant,mydin,lotus,99 speedmart,fresh,frutta,verdura,'
      'macelleria,panificio,forno,salumeria,pescheria'),
  DefaultCategory('Ristoranti e bar', 'restaurant', 0xFFE65100,
      'ristorante,trattoria,osteria,pizzeria,bar,caffè,caffe,cafe,café,pasticceria,gelateria,pub,birreria,'
      'paninoteca,rosticceria,kebab,sushi,mcdonald,burger king,kfc,starbucks,autogrill,restaurant,'
      'restoran,bistro,coffee,kopitiam,food,makan,mamak,bakery,tavola calda,coperto'),
  DefaultCategory('Trasporti', 'car', 0xFF1565C0,
      'carburante,benzina,gasolio,diesel,eni,agip,q8,esso,tamoil,shell,totalerg,erg,'
      'autostrada,autostrade,pedaggio,telepass,parcheggio,parking,trenitalia,italo,atac,gtt,'
      'taxi,uber,bus,metro,biglietto,fuel,petrol,petronas,caltex,toll,grab'),
  DefaultCategory('Casa e bollette', 'home', 0xFF6A1B9A,
      'enel,hera,a2a,iren,acea,edison,gas,luce,acqua,bolletta,affitto,condominio,tim,vodafone,'
      'windtre,iliad,fastweb,internet,ikea,leroy merlin,brico,ferramenta,hardware,electric,utility'),
  DefaultCategory('Salute', 'health', 0xFFC62828,
      'farmacia,parafarmacia,pharmacy,ospedale,medico,dentista,ottica,ottico,analisi,ticket,'
      'clinica,poliambulatorio,guardian,watsons,clinic'),
  DefaultCategory('Shopping', 'bag', 0xFFAD1457,
      'abbigliamento,scarpe,calzature,zara,h&m,decathlon,mediaworld,unieuro,euronics,amazon,'
      'libreria,feltrinelli,mondadori,profumeria,sephora,douglas,stationery,book,fashion,shoes,'
      'electronics,mall,store,boutique'),
  DefaultCategory('Svago', 'movie', 0xFF00838F,
      'cinema,teatro,museo,concerto,palestra,gym,piscina,netflix,spotify,steam,playstation,'
      'giochi,lotto,tabacchi,viaggio,hotel,albergo,b&b,airbnb,booking'),
  DefaultCategory('Altro', 'other', 0xFF546E7A, ''),
];
