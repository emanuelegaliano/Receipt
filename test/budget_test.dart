import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_app/data/budget.dart';
import 'package:receipt_app/data/database.dart';
import 'package:receipt_app/data/demo_data.dart';

void main() {
  test('fasce del limite', () {
    expect(budgetLevel(7999, 10000), BudgetLevel.ok);
    expect(budgetLevel(8000, 10000), BudgetLevel.near);
    expect(budgetLevel(10000, 10000), BudgetLevel.reached);
    expect(budgetLevel(500, 0), BudgetLevel.ok);
  });

  test('avvisi: al passaggio di soglia e oltre il limite', () {
    BudgetAlert? alert(int before, int after) =>
        budgetAlert(category: 'Svago', limit: 10000, before: before, after: after);

    expect(alert(1000, 5000), isNull);
    expect(alert(7000, 8500)!.level, BudgetLevel.near);
    expect(alert(8500, 9000), isNull, reason: 'già avvisato all\'80%');
    final reached = alert(9000, 11089)!;
    expect((reached.level, reached.crossed, reached.over), (BudgetLevel.reached, true, 1089));
    final again = alert(11089, 12000)!;
    expect((again.level, again.crossed), (BudgetLevel.reached, false));
    expect(alert(12000, 11000), isNull, reason: 'una spesa ridotta non avvisa');
    expect(budgetAlert(category: 'Altro', limit: null, before: 0, after: 99999), isNull);
  });

  group('database', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('speso per categoria nel mese, escludendo una spesa', () async {
      await loadDemoData(db, DateTime(2026, 10));
      final cats = {for (final c in await db.allCategories()) c.name: c};
      final svago = cats['Svago']!;
      expect(svago.monthlyLimitCents, 10000);
      expect(await db.categorySpent(svago.id, DateTime(2026, 10)), 11089);
      expect(await db.categorySpent(svago.id, DateTime(2026, 9)), 1600);
      expect(await db.categorySpent(cats['Salute']!.id, DateTime(2026, 11)), 0);

      final any = (await db.watchExpenses(DateTime(2026, 10), DateTime(2026, 11)).first)
          .firstWhere((e) => e.category.id == svago.id);
      expect(await db.categorySpent(svago.id, DateTime(2026, 10), exceptId: any.expense.id),
          11089 - any.expense.amountCents);
    });

    test('togliere il limite', () async {
      final c = (await db.allCategories()).first;
      await db.saveCategory(CategoriesCompanion(id: Value(c.id), monthlyLimitCents: const Value(5000)));
      await db.saveCategory(CategoriesCompanion(id: Value(c.id), monthlyLimitCents: const Value(null)));
      expect((await db.allCategories()).first.monthlyLimitCents, isNull);
    });
  });

  test('un database della versione 1 viene aggiornato senza perdere dati', () async {
    final dir = await Directory.systemTemp.createTemp('migr');
    final file = File('${dir.path}/db.sqlite');

    // Crea il database e lo riporta com'era nella versione 1.
    var db = AppDatabase(NativeDatabase(file));
    final cat = (await db.allCategories()).first;
    final acc = (await db.watchAccounts().first).first;
    await db.saveExpense(ExpensesCompanion.insert(
        amountCents: 1234, date: DateTime(2026, 10, 1), categoryId: cat.id, accountId: acc.id));
    await db.customStatement('ALTER TABLE categories DROP COLUMN monthly_limit_cents');
    await db.customStatement('PRAGMA user_version = 1');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    expect(await db.categorySpent(cat.id, DateTime(2026, 10)), 1234);
    expect((await db.allCategories()).first.monthlyLimitCents, isNull);
    await db.close();
    await dir.delete(recursive: true);
  });
}
