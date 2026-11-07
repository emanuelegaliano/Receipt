import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/common.dart' show CommonDatabase;

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

@DriftDatabase(tables: [Accounts, Categories, Expenses, MerchantRules, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seed();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.addColumn(categories, categories.monthlyLimitCents);
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

  Future<int> saveCategory(CategoriesCompanion c) async {
    if (c.id.present) {
      await (update(categories)..where((t) => t.id.equals(c.id.value))).write(c);
      return c.id.value;
    }
    final maxOrder = await (selectOnly(categories)..addColumns([categories.sortOrder.max()]))
        .map((r) => r.read(categories.sortOrder.max()))
        .getSingleOrNull();
    return into(categories).insert(c.copyWith(sortOrder: Value((maxOrder ?? 0) + 1)));
  }

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
        if (moveTo != null) {
          await (update(expenses)..where((e) => e.categoryId.equals(id)))
              .write(ExpensesCompanion(categoryId: Value(moveTo)));
          await (update(merchantRules)..where((r) => r.categoryId.equals(id)))
              .write(MerchantRulesCompanion(categoryId: Value(moveTo)));
        } else {
          await (delete(merchantRules)..where((r) => r.categoryId.equals(id))).go();
        }
        await (delete(categories)..where((c) => c.id.equals(id))).go();
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

  // --- Impostazioni --------------------------------------------------------

  Future<String?> setting(String key) async =>
      (await (select(settings)..where((s) => s.key.equals(key))).getSingleOrNull())?.value;

  Future<void> setSetting(String key, String value) =>
      into(settings).insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));
}

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
