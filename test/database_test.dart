import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_app/data/database.dart';
import 'package:receipt_app/receipt/categorizer.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('al primo avvio ci sono Carta, Contanti e le categorie di base', () async {
    final accounts = await db.watchAccounts().first;
    expect(accounts.map((a) => a.name), ['Carta', 'Contanti']);
    final cats = await db.allCategories();
    expect(cats.map((c) => c.name), defaultCategories.map((c) => c.name));
  });

  test('spese del mese, modifica ed eliminazione', () async {
    final cats = await db.allCategories();
    final accounts = await db.watchAccounts().first;
    Future<int> add(int cents, DateTime d) => db.saveExpense(ExpensesCompanion.insert(
          amountCents: cents,
          date: d,
          categoryId: cats.first.id,
          accountId: accounts.first.id,
          merchant: const Value('Conad'),
        ));

    final a = await add(1250, DateTime(2026, 10, 3));
    await add(800, DateTime(2026, 10, 31, 12));
    await add(999, DateTime(2026, 11, 1)); // mese dopo

    var oct = await db.watchExpenses(DateTime(2026, 10), DateTime(2026, 11)).first;
    expect(oct.map((e) => e.expense.amountCents), [800, 1250]); // più recente prima
    expect(oct.first.category.id, cats.first.id);

    await db.saveExpense(ExpensesCompanion(id: Value(a), amountCents: const Value(1300)));
    await db.deleteExpense(oct.first.expense.id);
    oct = await db.watchExpenses(DateTime(2026, 10), DateTime(2026, 11)).first;
    expect(oct.single.expense.amountCents, 1300);
    expect(await db.recentMerchants(), ['Conad']);

    // "Annulla" dopo l'eliminazione rimette la stessa spesa.
    final removed = oct.single.expense;
    await db.deleteExpense(removed.id);
    await db.restoreExpense(removed);
    expect(await db.expenseById(removed.id), removed);
  });

  test('le regole esercente si aggiornano con l\'ultima scelta', () async {
    final cats = await db.allCategories();
    final key = merchantKey('Bar Roma S.r.l.');
    await db.learnMerchant(key, cats[1].id);
    await db.learnMerchant(key, cats[1].id);
    await db.learnMerchant(key, cats[6].id);
    expect(await db.loadMerchantRules(), {key: cats[6].id});
  });

  test('impostazioni', () async {
    expect(await db.setting('receipt_lang'), isNull);
    await db.setSetting('receipt_lang', 'en');
    await db.setSetting('receipt_lang', 'it');
    expect(await db.setting('receipt_lang'), 'it');
  });
}
