import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../app_services.dart';
import '../data/database.dart';
import 'format.dart';
import 'l10n.dart';
import 'widgets.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppServices.of(context);
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.navCategories),
        actions: [
          IconButton(
            tooltip: l.newCategory,
            icon: const Icon(Icons.add),
            onPressed: () => showCategoryEditor(context),
          ),
        ],
      ),
      body: ValueListenableBuilder<DateTime>(
        valueListenable: services.month,
        builder: (context, month, _) => StreamBuilder<List<ExpenseView>>(
          stream: services.db.watchExpenses(month, nextMonth(month)),
          builder: (context, expSnap) {
            final totals = <int, int>{};
            final counts = <int, int>{};
            for (final e in expSnap.data ?? const <ExpenseView>[]) {
              totals[e.category.id] = (totals[e.category.id] ?? 0) + e.expense.amountCents;
              counts[e.category.id] = (counts[e.category.id] ?? 0) + 1;
            }
            return StreamBuilder<List<Category>>(
              stream: services.db.watchCategories(),
              builder: (context, snap) {
                final cats = snap.data ?? const <Category>[];
                return ListView(
                  padding: const EdgeInsets.only(bottom: 96),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Text(
                        l.categoriesIntro(month),
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ),
                    for (final c in cats)
                      ListTile(
                        leading: CategoryAvatar(c),
                        title: Text(categoryLabel(c, l)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.expenseCount(counts[c.id] ?? 0)),
                            if (c.monthlyLimitCents != null) ...[
                              const SizedBox(height: 6),
                              BudgetBar(spent: totals[c.id] ?? 0, limit: c.monthlyLimitCents!, color: Color(c.color)),
                              const SizedBox(height: 2),
                              Text(l.monthlyLimitPerMonth(formatCents(context, c.monthlyLimitCents!))),
                            ],
                          ],
                        ),
                        trailing: Text(formatCents(context, totals[c.id] ?? 0), style: Theme.of(context).textTheme.titleSmall),
                        onTap: () => showCategoryEditor(context, category: c),
                      ),
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

Future<void> showCategoryEditor(BuildContext context, {Category? category}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // Senza, il foglio aperto a tutta altezza finisce sotto la barra di
    // stato e il trattino per trascinarlo è irraggiungibile.
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _CategoryEditor(category: category, db: AppServices.of(context).db),
    ),
  );
}

class _CategoryEditor extends StatefulWidget {
  final Category? category;
  final AppDatabase db;
  const _CategoryEditor({this.category, required this.db});

  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  // Le categorie predefinite si aprono col nome nella lingua dell'app.
  late final _name = TextEditingController(
    text: widget.category == null ? '' : categoryLabel(widget.category!, context.l10n),
  );
  late final _keywords = TextEditingController(text: widget.category?.keywords.replaceAll(',', ', ') ?? '');
  late String _icon = widget.category?.icon ?? 'other';
  late int _color = widget.category?.color ?? categoryColors.first;
  late final _limit = TextEditingController(
    text: widget.category?.monthlyLimitCents == null ? '' : centsToInput(context, widget.category!.monthlyLimitCents!),
  );
  String? _limitError;

  @override
  void dispose() {
    _name.dispose();
    _keywords.dispose();
    _limit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    var name = _name.text.trim();
    if (name.isEmpty) return;
    // Nome predefinito non toccato: resta quello italiano, che segue la lingua.
    final cat = widget.category;
    if (cat != null && name == categoryLabel(cat, context.l10n)) name = cat.name;
    final limit = _limit.text.trim().isEmpty ? null : parseCents(_limit.text);
    if (_limit.text.trim().isNotEmpty && (limit == null || limit <= 0)) {
      setState(() => _limitError = context.l10n.limitInvalid);
      return;
    }
    final keywords = _keywords.text.split(',').map((k) => k.trim().toLowerCase()).where((k) => k.isNotEmpty).join(',');
    await widget.db.saveCategory(CategoriesCompanion(
      id: widget.category == null ? const Value.absent() : Value(widget.category!.id),
      name: Value(name),
      icon: Value(_icon),
      color: Value(_color),
      keywords: Value(keywords),
      monthlyLimitCents: Value(limit),
    ));
    if (mounted) Navigator.pop(context);
  }

  /// Elimina la categoria. Se ha spese, prima chiede in quale categoria
  /// spostarle: lo storico non si perde.
  Future<void> _delete() async {
    final cat = widget.category!;
    final others = (await widget.db.allCategories()).where((c) => c.id != cat.id).toList();
    final count = await widget.db.categoryExpenseCount(cat.id);
    if (!mounted) return;
    final l = context.l10n;
    final name = categoryLabel(cat, l);
    if (count > 0 && others.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.onlyCategory)));
      return;
    }
    var moveTo = (others.where((c) => c.name == 'Altro').firstOrNull ?? others.firstOrNull)?.id;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(l.deleteCategoryTitle(name)),
          content: count == 0
              ? Text(l.categoryEmpty)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.moveExpensesTo(count, name)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: moveTo,
                      isExpanded: true,
                      items: [
                        for (final c in others)
                          DropdownMenuItem(
                            value: c.id,
                            child: Row(children: [
                              CategoryAvatar(c, size: 28),
                              const SizedBox(width: 10),
                              Flexible(child: Text(categoryLabel(c, l), overflow: TextOverflow.ellipsis)),
                            ]),
                          ),
                      ],
                      onChanged: (v) => setDialog(() => moveTo = v),
                    ),
                  ],
                ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
                foregroundColor: Theme.of(ctx).colorScheme.onError,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(count == 0 ? l.delete : l.moveAndDelete),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await widget.db.deleteCategory(cat.id, moveTo: count == 0 ? null : moveTo);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final l = context.l10n;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.category == null ? l.newCategory : l.editCategory, style: text.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            autofocus: widget.category == null,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l.name),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _limit,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l.monthlyLimitLabel,
              suffixText: '€',
              errorText: _limitError,
              helperText: l.monthlyLimitHelper,
              helperMaxLines: 2,
            ),
          ),
          const SizedBox(height: 16),
          Text(l.icon, style: text.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in categoryIcons.entries)
                IconButton.filledTonal(
                  isSelected: _icon == e.key,
                  onPressed: () => setState(() => _icon = e.key),
                  icon: Icon(e.value),
                  style: IconButton.styleFrom(
                    backgroundColor: _icon == e.key ? Color(_color).withValues(alpha: 0.25) : null,
                    foregroundColor: _icon == e.key ? Color(_color) : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(l.color, style: text.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in categoryColors)
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: Border.all(color: _color == c ? scheme.onSurface : Colors.transparent, width: 3),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _keywords,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: l.keywords,
              helperText: l.keywordsHelper,
              helperMaxLines: 4,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              if (widget.category != null)
                TextButton.icon(
                  onPressed: _delete,
                  style: TextButton.styleFrom(foregroundColor: scheme.error),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(l.delete),
                ),
              const Spacer(),
              FilledButton(onPressed: _save, child: Text(l.save)),
            ],
          ),
        ],
      ),
    );
  }
}
