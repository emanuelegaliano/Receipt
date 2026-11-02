import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_services.dart';
import '../data/budget.dart';
import '../data/database.dart';
import 'expense_form_screen.dart';
import 'format.dart';
import 'l10n.dart';

/// ‹ Novembre 2026 ›: cambia il mese condiviso da riepilogo e movimenti.
/// Toccando il nome del mese si sceglie mese e anno da una griglia.
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
              width: 190,
              child: TextButton(
                onPressed: () async {
                  final picked = await showMonthPicker(context, initial: m);
                  if (picked != null) month.value = picked;
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(formatMonth(context, m),
                          overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
                    ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
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

/// Griglia dei 12 mesi con l'anno da cambiare in alto: per saltare a un
/// mese lontano senza premere ‹ decine di volte. I mesi futuri sono spenti,
/// come la freccia › nel MonthSwitcher.
Future<DateTime?> showMonthPicker(BuildContext context, {required DateTime initial}) =>
    showDialog<DateTime>(context: context, builder: (_) => _MonthPickerDialog(initial));

class _MonthPickerDialog extends StatefulWidget {
  final DateTime initial;
  const _MonthPickerDialog(this.initial);

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  static const firstYear = 2000; // come il calendario del modulo spesa
  late int _year = widget.initial.year;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final now = monthOf(DateTime.now());
    final names = DateFormat.MMM(context.localeTag);
    return AlertDialog(
      title: Text(l.chooseMonth),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: l.previousYear,
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _year > firstYear ? () => setState(() => _year--) : null,
                ),
                Text('$_year', style: Theme.of(context).textTheme.titleLarge),
                IconButton(
                  tooltip: l.nextYear,
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _year < now.year ? () => setState(() => _year++) : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              childAspectRatio: 2.2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var i = 1; i <= 12; i++)
                  () {
                    final m = DateTime(_year, i);
                    final label = names.format(m);
                    final text = Text(label[0].toUpperCase() + label.substring(1));
                    final enabled = !m.isAfter(now);
                    if (m == widget.initial) {
                      return FilledButton(onPressed: () => Navigator.pop(context, m), child: text);
                    }
                    return OutlinedButton(
                      onPressed: enabled ? () => Navigator.pop(context, m) : null,
                      style: m == now ? OutlinedButton.styleFrom(side: BorderSide(color: scheme.primary)) : null,
                      child: text,
                    );
                  }(),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, now), child: Text(l.thisMonth)),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
      ],
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
