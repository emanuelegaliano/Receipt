import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../app_services.dart';
import '../data/database.dart';
import 'format.dart';
import 'settings_screen.dart';
import 'widgets.dart';

class DashboardScreen extends StatelessWidget {
  final VoidCallback onSeeAll;
  const DashboardScreen({super.key, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    final services = AppServices.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riepilogo'),
        actions: [
          IconButton(
            tooltip: 'Impostazioni',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: ValueListenableBuilder<DateTime>(
        valueListenable: services.month,
        builder: (context, month, _) => StreamBuilder<List<ExpenseView>>(
          stream: services.db.watchExpenses(DateTime(month.year, month.month - 1), nextMonth(month)),
          builder: (context, snap) {
            final all = snap.data ?? const <ExpenseView>[];
            final current = all.where((e) => !e.expense.date.isBefore(month)).toList();
            final previous = all.where((e) => e.expense.date.isBefore(month)).toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              children: [
                const MonthSwitcher(),
                const SizedBox(height: 8),
                _TotalCard(month: month, current: current, previous: previous),
                const SizedBox(height: 16),
                if (current.isEmpty && snap.hasData)
                  const EmptyState(
                    icon: Icons.savings_outlined,
                    title: 'Nessuna spesa questo mese',
                    message: 'Tocca "Aggiungi" per fotografare uno scontrino o inserire una spesa a mano.',
                  )
                else if (current.isNotEmpty) ...[
                  _CategoryBreakdown(current),
                  const SizedBox(height: 16),
                  _Recent(current, onSeeAll: onSeeAll),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

int _sum(Iterable<ExpenseView> xs) => xs.fold(0, (s, e) => s + e.expense.amountCents);

class _TotalCard extends StatelessWidget {
  final DateTime month;
  final List<ExpenseView> current;
  final List<ExpenseView> previous;
  const _TotalCard({required this.month, required this.current, required this.previous});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final total = _sum(current);
    final prevTotal = _sum(previous);

    // Totale per conto (Carta, Contanti, ...).
    final byAccount = <int, (Account, int)>{};
    for (final e in current) {
      final prev = byAccount[e.account.id];
      byAccount[e.account.id] = (e.account, (prev?.$2 ?? 0) + e.expense.amountCents);
    }

    String? comparison;
    if (prevTotal > 0) {
      final pct = ((total - prevTotal) / prevTotal * 100).round();
      final prevName = formatMonth(DateTime(month.year, month.month - 1)).split(' ').first.toLowerCase();
      comparison = pct == 0 ? 'Come a $prevName' : '${pct > 0 ? '+' : ''}$pct% rispetto a $prevName';
    }

    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Speso questo mese', style: text.labelLarge?.copyWith(color: scheme.onPrimaryContainer)),
            const SizedBox(height: 4),
            Text(formatCents(total),
                style: text.displaySmall?.copyWith(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w600)),
            if (comparison != null) ...[
              const SizedBox(height: 2),
              Text(comparison, style: text.bodyMedium?.copyWith(color: scheme.onPrimaryContainer)),
            ],
            if (byAccount.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (account, cents) in byAccount.values)
                    Chip(
                      avatar: Icon(accountIcon(account.kind), size: 18),
                      label: Text('${account.name} ${formatCents(cents)}'),
                      backgroundColor: scheme.surface.withValues(alpha: 0.6),
                      side: BorderSide.none,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryBreakdown extends StatefulWidget {
  final List<ExpenseView> items;
  const _CategoryBreakdown(this.items);

  @override
  State<_CategoryBreakdown> createState() => _CategoryBreakdownState();
}

class _CategoryBreakdownState extends State<_CategoryBreakdown> {
  int? _touched;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final totals = <int, (Category, int)>{};
    for (final e in widget.items) {
      final prev = totals[e.category.id];
      totals[e.category.id] = (e.category, (prev?.$2 ?? 0) + e.expense.amountCents);
    }
    final rows = totals.values.toList()..sort((a, b) => b.$2.compareTo(a.$2));
    final total = _sum(widget.items);

    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Per categoria', style: text.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 190,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 58,
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          if (!event.isInterestedForInteractions) return;
                          setState(() => _touched = response?.touchedSection?.touchedSectionIndex);
                        },
                      ),
                      sections: [
                        for (var i = 0; i < rows.length; i++)
                          PieChartSectionData(
                            value: rows[i].$2.toDouble(),
                            color: Color(rows[i].$1.color),
                            radius: _touched == i ? 34 : 28,
                            showTitle: false,
                          ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _touched != null && _touched! >= 0 && _touched! < rows.length ? rows[_touched!].$1.name : 'Totale',
                        style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      Text(
                        formatCents(_touched != null && _touched! >= 0 && _touched! < rows.length ? rows[_touched!].$2 : total),
                        style: text.titleMedium,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            for (final (cat, cents) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    CategoryAvatar(cat, size: 34),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(cat.name, style: text.bodyLarge)),
                              Text(formatCents(cents), style: text.titleSmall),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: total == 0 ? 0 : cents / total,
                                    minHeight: 6,
                                    color: Color(cat.color),
                                    backgroundColor: scheme.surfaceContainerHighest,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 40,
                                child: Text(
                                  '${(total == 0 ? 0 : cents * 100 / total).round()}%',
                                  textAlign: TextAlign.end,
                                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Recent extends StatelessWidget {
  final List<ExpenseView> items;
  final VoidCallback onSeeAll;
  const _Recent(this.items, {required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            title: Text('Ultimi movimenti', style: Theme.of(context).textTheme.titleMedium),
            trailing: TextButton(onPressed: onSeeAll, child: const Text('Vedi tutti')),
          ),
          for (final e in items.take(5)) ExpenseTile(e, showDate: true),
        ],
      ),
    );
  }
}
