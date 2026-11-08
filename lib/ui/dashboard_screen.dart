import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_services.dart';
import '../art/art_ui.dart';
import '../data/budget.dart';
import '../data/database.dart';
import '../island/island_ui.dart';
import 'format.dart';
import 'l10n.dart';
import 'settings_screen.dart';
import 'widgets.dart';

class DashboardScreen extends StatelessWidget {
  final VoidCallback onSeeAll;
  const DashboardScreen({super.key, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    final services = AppServices.of(context);
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.summaryTitle),
        actions: [
          const IslandButton(),
          const PaintingInfoButton(),
          IconButton(
            tooltip: l.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: ValueListenableBuilder<DateTime>(
        valueListenable: services.month,
        // Sei mesi fino a quello scelto: servono per le colonne sotto il totale
        // e per il confronto col mese prima.
        builder: (context, month, _) => StreamBuilder<List<ExpenseView>>(
          stream: services.db.watchExpenses(DateTime(month.year, month.month - 5), nextMonth(month)),
          builder: (context, snap) {
            final all = snap.data ?? const <ExpenseView>[];
            final prevMonth = DateTime(month.year, month.month - 1);
            final current = all.where((e) => !e.expense.date.isBefore(month)).toList();
            final previous =
                all.where((e) => !e.expense.date.isBefore(prevMonth) && e.expense.date.isBefore(month)).toList();
            final history = [
              for (var i = 5; i >= 0; i--)
                (
                  DateTime(month.year, month.month - i),
                  _sum(all.where((e) => monthOf(e.expense.date) == DateTime(month.year, month.month - i))),
                ),
            ];
            return StreamBuilder<List<Category>>(
              stream: services.db.watchCategories(),
              builder: (context, catSnap) {
                final hasLimits = (catSnap.data ?? const <Category>[]).any((c) => c.monthlyLimitCents != null);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  children: [
                    const MonthSwitcher(),
                    const SizedBox(height: 8),
                    _TotalCard(month: month, current: current, previous: previous, history: history),
                    const SizedBox(height: 16),
                    if (current.isNotEmpty || hasLimits) ...[
                      _Categories(
                        categories: catSnap.data ?? const [],
                        current: current,
                        previous: previous,
                        previousMonth: prevMonth,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (current.isEmpty && snap.hasData)
                      EmptyState(
                        icon: Icons.savings_outlined,
                        title: l.noSpendingTitle,
                        message: l.noSpendingMessage,
                      )
                    else if (current.isNotEmpty)
                      _Recent(current, onSeeAll: onSeeAll),
                  ],
                );
              },
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
  final List<(DateTime, int)> history;
  const _TotalCard({required this.month, required this.current, required this.previous, required this.history});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
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
      final prev = DateTime(month.year, month.month - 1);
      comparison = pct == 0
          ? l.sameAsMonth(monthPrep(prev), prev)
          : l.percentVsMonth('${pct > 0 ? '+' : ''}$pct', monthPrep(prev), prev);
    }

    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.spentThisMonth, style: text.labelLarge?.copyWith(color: scheme.onPrimaryContainer)),
            const SizedBox(height: 4),
            Text(formatCents(context, total),
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
                      label: Text('${accountLabel(account, l)} ${formatCents(context, cents)}'),
                      backgroundColor: scheme.surface.withValues(alpha: 0.6),
                      side: BorderSide.none,
                    ),
                ],
              ),
            ],
            if (history.any((h) => h.$2 > 0)) ...[
              const SizedBox(height: 20),
              _MonthsChart(history: history, selected: month),
            ],
          ],
        ),
      ),
    );
  }
}

/// Colonne degli ultimi sei mesi: il mese scelto pieno, gli altri attenuati.
/// Niente valori sulle colonne (il totale del mese è già scritto sopra):
/// toccandone una si passa a quel mese.
class _MonthsChart extends StatelessWidget {
  final List<(DateTime, int)> history;
  final DateTime selected;
  const _MonthsChart({required this.history, required this.selected});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final ink = scheme.onPrimaryContainer;
    final maxY = history.map((h) => h.$2).reduce(math.max).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.last6Months, style: text.labelMedium?.copyWith(color: ink.withValues(alpha: 0.8))),
        const SizedBox(height: 8),
        SizedBox(
          height: 96,
          child: BarChart(
            BarChartData(
              maxY: maxY * 1.25,
              minY: 0,
              alignment: BarChartAlignment.spaceAround,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    getTitlesWidget: (v, meta) {
                      final (m, _) = history[v.toInt()];
                      final isSel = m == selected;
                      return SideTitleWidget(
                        meta: meta,
                        space: 4,
                        child: Text(
                          DateFormat.MMM(context.localeTag).format(m).replaceAll('.', ''),
                          style: text.labelSmall?.copyWith(
                            color: ink.withValues(alpha: isSel ? 1 : 0.7),
                            fontWeight: isSel ? FontWeight.w700 : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                handleBuiltInTouches: false,
                touchCallback: (event, response) {
                  final i = response?.spot?.touchedBarGroupIndex;
                  if (event is FlTapUpEvent && i != null) AppServices.of(context).month.value = history[i].$1;
                },
                touchTooltipData: BarTouchTooltipData(getTooltipItem: (_, _, _, _) => null),
              ),
              barGroups: [
                for (var i = 0; i < history.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: history[i].$2.toDouble(),
                        width: 20,
                        color: ink.withValues(alpha: history[i].$1 == selected ? 1 : 0.3),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Una riga per categoria: quanto hai speso (barra), dov'eri il mese prima
/// (pallino) e il limite (tacca). Tutte le barre hanno la stessa scala,
/// così le lunghezze si confrontano tra loro.
class _Categories extends StatelessWidget {
  final List<Category> categories;
  final List<ExpenseView> current;
  final List<ExpenseView> previous;
  final DateTime previousMonth;
  const _Categories({
    required this.categories,
    required this.current,
    required this.previous,
    required this.previousMonth,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    Map<int, int> totals(List<ExpenseView> xs) {
      final m = <int, int>{};
      for (final e in xs) {
        m[e.category.id] = (m[e.category.id] ?? 0) + e.expense.amountCents;
      }
      return m;
    }

    final now = totals(current), before = totals(previous);
    // Anche le categorie archiviate, se hanno spese nel mese.
    final byId = {for (final c in categories) c.id: c, for (final e in current) e.category.id: e.category};
    final rows = [
      for (final c in byId.values)
        if ((now[c.id] ?? 0) > 0 || c.monthlyLimitCents != null) (c, now[c.id] ?? 0, before[c.id] ?? 0),
    ]..sort((a, b) => b.$2 != a.$2 ? b.$2.compareTo(a.$2) : a.$1.sortOrder.compareTo(b.$1.sortOrder));
    final scale = rows.fold<int>(1, (m, r) => math.max(m, math.max(r.$2, math.max(r.$3, r.$1.monthlyLimitCents ?? 0))));
    final showLimitKey = rows.any((r) => r.$1.monthlyLimitCents != null);
    final showPrevKey = rows.any((r) => r.$3 > 0);

    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.byCategory, style: text.titleMedium),
            if (showPrevKey || showLimitKey) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  if (showPrevKey)
                    _Key(marker: _Marker.previous, label: DateFormat.MMMM(context.localeTag).format(previousMonth)),
                  if (showLimitKey) _Key(marker: _Marker.limit, label: l.legendLimit),
                ],
              ),
            ],
            const SizedBox(height: 4),
            for (final (cat, cents, prev) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CategoryAvatar(cat, size: 34),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(categoryLabel(cat, l), style: text.bodyLarge)),
                              Text(formatCents(context, cents), style: text.titleSmall),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _CategoryBar(
                            spent: cents,
                            previous: prev,
                            limit: cat.monthlyLimitCents,
                            scale: scale,
                            color: Color(cat.color),
                          ),
                          const SizedBox(height: 4),
                          _RowNote(spent: cents, previous: prev, limit: cat.monthlyLimitCents, previousMonth: previousMonth),
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

enum _Marker { previous, limit }

class _Key extends StatelessWidget {
  final _Marker marker;
  final String label;
  const _Key({required this.marker, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(14, 14),
          painter: _MarkerPainter(marker, scheme.onSurfaceVariant, scheme.surface),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
      ],
    );
  }
}

class _MarkerPainter extends CustomPainter {
  final _Marker marker;
  final Color color, surface;
  _MarkerPainter(this.marker, this.color, this.surface);

  @override
  void paint(Canvas canvas, Size size) => _paintMarker(canvas, marker, size.width / 2, size.height, color, surface);

  @override
  bool shouldRepaint(_MarkerPainter old) => old.color != color || old.surface != surface;
}

/// Pallino (mese prima) o tacca verticale (limite) centrati in [x].
void _paintMarker(Canvas canvas, _Marker marker, double x, double height, Color color, Color surface) {
  final mid = height / 2;
  switch (marker) {
    case _Marker.previous:
      canvas.drawCircle(Offset(x, mid), 6, Paint()..color = surface);
      canvas.drawCircle(Offset(x, mid), 4, Paint()..color = color);
    case _Marker.limit:
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x - 1.5, 0, 3, height), const Radius.circular(1.5)),
        Paint()..color = color,
      );
  }
}

class _CategoryBar extends StatelessWidget {
  final int spent, previous;
  final int? limit;
  final int scale;
  final Color color;
  const _CategoryBar({
    required this.spent,
    required this.previous,
    required this.limit,
    required this.scale,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = limit == null
        ? color
        : switch (budgetLevel(spent, limit!)) {
            BudgetLevel.ok => color,
            BudgetLevel.near => const Color(0xFFF59E0B),
            BudgetLevel.reached => scheme.error,
          };
    return SizedBox(
      height: 18,
      width: double.infinity,
      child: CustomPaint(
        painter: _BarPainter(
          spent: spent / scale,
          previous: previous > 0 ? previous / scale : null,
          limit: limit == null ? null : limit! / scale,
          fill: fill,
          track: scheme.surfaceContainerHighest,
          marker: scheme.onSurface,
          surface: scheme.surface,
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  final double spent;
  final double? previous, limit;
  final Color fill, track, marker, surface;
  _BarPainter({
    required this.spent,
    required this.previous,
    required this.limit,
    required this.fill,
    required this.track,
    required this.marker,
    required this.surface,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const barH = 10.0;
    final top = (size.height - barH) / 2;
    // Margine a destra: i segni a fine scala non devono uscire.
    final w = size.width - 6;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, top, w, barH), const Radius.circular(4)),
      Paint()..color = track,
    );
    if (spent > 0) {
      final len = math.max(4.0, w * spent.clamp(0, 1));
      // Estremità arrotondata dalla parte del valore, dritta all'inizio.
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(0, top, len, barH),
          topRight: const Radius.circular(4),
          bottomRight: const Radius.circular(4),
        ),
        Paint()..color = fill,
      );
    }
    if (limit != null) _paintMarker(canvas, _Marker.limit, w * limit!.clamp(0, 1), size.height, marker, surface);
    if (previous != null) {
      _paintMarker(canvas, _Marker.previous, w * previous!.clamp(0, 1), size.height, marker, surface);
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.spent != spent || old.previous != previous || old.limit != limit || old.fill != fill || old.track != track;
}

/// "+12,30 € rispetto a settembre · Restano 22,04 €"
class _RowNote extends StatelessWidget {
  final int spent, previous;
  final int? limit;
  final DateTime previousMonth;
  const _RowNote({required this.spent, required this.previous, required this.limit, required this.previousMonth});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final l = context.l10n;
    final prep = monthPrep(previousMonth);
    final parts = <InlineSpan>[];
    final diff = spent - previous;
    if (previous > 0) {
      parts.add(TextSpan(
        text: diff == 0
            ? l.sameAsMonth(prep, previousMonth)
            : l.amountVsMonth('${diff > 0 ? '+' : '−'}${formatCents(context, diff.abs())}', prep, previousMonth),
      ));
    } else if (spent > 0) {
      parts.add(TextSpan(text: l.nothingInMonth(prep, previousMonth)));
    }
    if (limit != null) {
      if (parts.isNotEmpty) parts.add(const TextSpan(text: ' · '));
      parts.add(switch (budgetLevel(spent, limit!)) {
        BudgetLevel.ok => TextSpan(text: l.remaining(formatCents(context, limit! - spent))),
        BudgetLevel.near => TextSpan(
            text: l.remaining(formatCents(context, limit! - spent)),
            style: TextStyle(color: warningColor(context), fontWeight: FontWeight.w600),
          ),
        BudgetLevel.reached => TextSpan(
            text: spent == limit ? l.limitExhausted : l.overBy(formatCents(context, spent - limit!)),
            style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600),
          ),
      });
    }
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text.rich(TextSpan(children: parts), style: style);
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
            title: Text(context.l10n.recentTransactions, style: Theme.of(context).textTheme.titleMedium),
            trailing: TextButton(onPressed: onSeeAll, child: Text(context.l10n.seeAll)),
          ),
          for (final e in items.take(5)) ExpenseTile(e, showDate: true),
        ],
      ),
    );
  }
}
