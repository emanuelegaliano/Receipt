import 'package:flutter/material.dart';

import '../app_services.dart';
import '../data/budget.dart';
import '../data/database.dart';
import 'expense_form_screen.dart';
import 'format.dart';
import 'l10n.dart';

/// ‹ Novembre 2026 › — cambia il mese condiviso da riepilogo e movimenti.
class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final month = AppServices.of(context).month;
    return ValueListenableBuilder<DateTime>(
      valueListenable: month,
      builder: (context, m, _) {
        final isCurrent = monthOf(DateTime.now()) == m;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: context.l10n.previousMonth,
              icon: const Icon(Icons.chevron_left),
              onPressed: () => month.value = DateTime(m.year, m.month - 1),
            ),
            SizedBox(
              width: 170,
              child: Text(formatMonth(context, m), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            ),
            IconButton(
              tooltip: context.l10n.nextMonth,
              icon: const Icon(Icons.chevron_right),
              onPressed: isCurrent ? null : () => month.value = nextMonth(m),
            ),
          ],
        );
      },
    );
  }
}

/// Riga di una spesa nelle liste.
class ExpenseTile extends StatelessWidget {
  final ExpenseView item;
  final bool showDate;
  const ExpenseTile(this.item, {super.key, this.showDate = false});

  @override
  Widget build(BuildContext context) {
    final e = item.expense;
    final scheme = Theme.of(context).colorScheme;
    final category = categoryLabel(item.category, context.l10n);
    final subtitle = [
      category,
      if (showDate) formatShortDate(context, e.date),
      if (e.note.isNotEmpty) e.note,
    ].join(' · ');
    return ListTile(
      leading: CategoryAvatar(item.category),
      title: Text(e.merchant.isEmpty ? category : e.merchant, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(formatCents(context, e.amountCents), style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (e.receiptPath != null) Icon(Icons.receipt_outlined, size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Icon(accountIcon(item.account.kind), size: 14, color: scheme.onSurfaceVariant),
            ],
          ),
        ],
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ExpenseFormScreen(expenseId: e.id)),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const EmptyState({super.key, required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 56, color: scheme.primary),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(message, style: TextStyle(color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// Arancio leggibile sia sul tema chiaro sia su quello scuro.
Color warningColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);

/// Barra di avanzamento verso un limite mensile: colore della categoria,
/// arancio oltre l'80%, rosso al limite.
class BudgetBar extends StatelessWidget {
  final int spent, limit;
  final Color color;
  final double height;
  const BudgetBar({super.key, required this.spent, required this.limit, required this.color, this.height = 6});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final barColor = switch (budgetLevel(spent, limit)) {
      BudgetLevel.ok => color,
      BudgetLevel.near => const Color(0xFFF59E0B),
      BudgetLevel.reached => scheme.error,
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: (spent / limit).clamp(0, 1).toDouble(),
        minHeight: height,
        color: barColor,
        backgroundColor: scheme.surfaceContainerHighest,
      ),
    );
  }
}
