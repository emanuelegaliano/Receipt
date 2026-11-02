import 'package:flutter/material.dart';

import '../app_services.dart';
import '../art/art_ui.dart';
import '../data/database.dart';
import 'format.dart';
import 'l10n.dart';
import 'widgets.dart';

/// Movimenti del mese raggruppati per giorno, con ricerca e filtri.
class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  String _query = '';
  int? _accountFilter;
  int? _categoryFilter;

  bool _matches(ExpenseView e) {
    if (_accountFilter != null && e.account.id != _accountFilter) return false;
    if (_categoryFilter != null && e.category.id != _categoryFilter) return false;
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return e.expense.merchant.toLowerCase().contains(q) ||
        e.expense.note.toLowerCase().contains(q) ||
        e.category.name.toLowerCase().contains(q) ||
        categoryLabel(e.category, context.l10n).toLowerCase().contains(q);
  }

  Future<void> _deleteWithUndo(ExpenseView item) async {
    final db = AppServices.of(context).db;
    final e = item.expense;
    await db.deleteExpense(e.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(context.l10n.expenseDeleted(formatCents(context, e.amountCents))),
        action: SnackBarAction(
          label: context.l10n.undo,
          onPressed: () => db.restoreExpense(e),
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final services = AppServices.of(context);
    final scheme = Theme.of(context).colorScheme;
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.navTransactions), actions: const [PaintingInfoButton()]),
      body: ValueListenableBuilder<DateTime>(
        valueListenable: services.month,
        builder: (context, month, _) => StreamBuilder<List<ExpenseView>>(
          stream: services.db.watchExpenses(month, nextMonth(month)),
          builder: (context, snap) {
            final all = snap.data ?? const <ExpenseView>[];
            final items = all.where(_matches).toList();
            final accounts = {for (final e in all) e.account.id: e.account}.values.toList();
            final categories = {for (final e in all) e.category.id: e.category}.values.toList();

            // Raggruppa per giorno (la lista arriva già ordinata per data).
            final groups = <DateTime, List<ExpenseView>>{};
            for (final e in items) {
              final d = e.expense.date;
              groups.putIfAbsent(DateTime(d.year, d.month, d.day), () => []).add(e);
            }

            return CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: MonthSwitcher()),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: TextField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: l.searchHint,
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _query = v.trim()),
                    ),
                  ),
                ),
                if (accounts.length > 1 || categories.length > 1)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 48,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          for (final a in accounts)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                avatar: Icon(accountIcon(a.kind), size: 18),
                                label: Text(accountLabel(a, l)),
                                selected: _accountFilter == a.id,
                                onSelected: (s) => setState(() => _accountFilter = s ? a.id : null),
                              ),
                            ),
                          for (final c in categories)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                avatar: Icon(iconOf(c), size: 18, color: Color(c.color)),
                                label: Text(categoryLabel(c, l)),
                                selected: _categoryFilter == c.id,
                                onSelected: (s) => setState(() => _categoryFilter = s ? c.id : null),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (snap.hasData && items.isEmpty)
                  SliverToBoxAdapter(
                    child: all.isEmpty
                        ? EmptyState(
                            icon: Icons.receipt_long_outlined,
                            title: l.noTransactionsTitle,
                            message: l.noTransactionsMessage,
                          )
                        : EmptyState(
                            icon: Icons.search_off,
                            title: l.noResultsTitle,
                            message: l.noResultsMessage,
                          ),
                  ),
                for (final entry in groups.entries) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(formatDay(context, entry.key),
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.primary)),
                          ),
                          Text(formatCents(context, entry.value.fold(0, (s, e) => s + e.expense.amountCents)),
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ),
                  SliverList.list(
                    children: [
                      for (final e in entry.value)
                        Dismissible(
                          key: ValueKey(e.expense.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: scheme.errorContainer,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
                          ),
                          onDismissed: (_) => _deleteWithUndo(e),
                          child: ExpenseTile(e),
                        ),
                    ],
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 96)),
              ],
            );
          },
        ),
      ),
    );
  }
}
