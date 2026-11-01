import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../app_services.dart';
import '../data/budget.dart';
import '../data/database.dart';
import '../receipt/categorizer.dart';
import 'format.dart';
import 'l10n.dart';

/// Dati precompilati da uno scontrino scansionato.
class ScanDraft {
  final Uint8List imageBytes;
  final int? amountCents;
  final DateTime? date;
  final String merchant;
  final String ocrText;
  final int? categoryId;
  final String? categoryReason;
  final int? accountId;
  final List<String> warnings;

  const ScanDraft({
    required this.imageBytes,
    required this.amountCents,
    required this.date,
    required this.merchant,
    required this.ocrText,
    this.categoryId,
    this.categoryReason,
    this.accountId,
    this.warnings = const [],
  });
}

class ExpenseFormScreen extends StatefulWidget {
  final int? expenseId;
  final ScanDraft? draft;
  const ExpenseFormScreen({super.key, this.expenseId, this.draft});

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _amount = TextEditingController();
  final _merchant = TextEditingController();
  final _note = TextEditingController();
  final _merchantFocus = FocusNode();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Quando si esce dal campo esercente si ricalcola la categoria suggerita.
    _merchantFocus.addListener(() {
      if (!_merchantFocus.hasFocus) _resuggestCategory();
    });
  }

  late AppDatabase _db;
  bool _loaded = false;
  bool _saving = false;
  Expense? _existing;

  DateTime _date = DateTime.now();
  int? _categoryId;
  int? _accountId;
  String? _categoryReason;
  bool _categoryTouched = false;
  List<String> _merchants = const [];
  List<Category> _categories = const [];
  Map<String, int> _rules = const {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    _db = AppServices.of(context).db;
    _load();
  }

  Future<void> _load() async {
    final merchants = await _db.recentMerchants();
    final categories = await _db.allCategories();
    final rules = await _db.loadMerchantRules();
    final accounts = await _db.watchAccounts().first;
    Expense? existing;
    if (widget.expenseId != null) existing = await _db.expenseById(widget.expenseId!);
    final lastAccount = await _db.setting('last_account');

    if (!mounted) return;
    setState(() {
      _merchants = merchants;
      _categories = categories;
      _rules = rules;
      _existing = existing;
      if (existing != null) {
        _amount.text = centsToInput(context, existing.amountCents);
        _merchant.text = existing.merchant;
        _note.text = existing.note;
        _date = existing.date;
        _categoryId = existing.categoryId;
        _accountId = existing.accountId;
        _categoryTouched = true;
      } else {
        final d = widget.draft;
        if (d != null) {
          if (d.amountCents != null) _amount.text = centsToInput(context, d.amountCents!);
          _merchant.text = d.merchant;
          _date = d.date ?? DateTime.now();
          _categoryId = d.categoryId;
          _categoryReason = d.categoryReason;
          _accountId = d.accountId;
        }
        _accountId ??= int.tryParse(lastAccount ?? '') ?? (accounts.isEmpty ? null : accounts.first.id);
      }
    });
  }

  void _resuggestCategory() {
    if (_categoryTouched) return;
    final s = suggestCategory(
      merchant: _merchant.text,
      ocrText: widget.draft?.ocrText ?? '',
      rules: _rules,
      categories: [for (final c in _categories) CategoryKeywords.parse(c.id, c.keywords)],
    );
    if (s.categoryId != null) {
      setState(() {
        _categoryId = s.categoryId;
        _categoryReason = describeSuggestion(s, context.l10n, fromReceipt: widget.draft != null);
      });
    }
  }

  Future<String?> _storeReceipt(Uint8List bytes) async {
    final dir = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'receipts'));
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, 'scontrino_${DateTime.now().millisecondsSinceEpoch}.jpg'));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final l = context.l10n;
    if (_categoryId == null || _accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.chooseCategory)));
      return;
    }
    setState(() => _saving = true);
    try {
      String? receiptPath = _existing?.receiptPath;
      if (widget.draft != null && receiptPath == null) receiptPath = await _storeReceipt(widget.draft!.imageBytes);

      final merchant = _merchant.text.trim();
      final cents = parseCents(_amount.text)!;
      final day = DateTime(_date.year, _date.month, _date.day, 12);
      final category = _categories.firstWhere((c) => c.id == _categoryId);
      // Speso nella categoria prima e dopo questa spesa, per l'avviso sul limite.
      final others = await _db.categorySpent(category.id, day, exceptId: _existing?.id);
      final old = _existing;
      final wasHere = old != null && old.categoryId == category.id && monthOf(old.date) == monthOf(day);
      final alert = budgetAlert(
        category: categoryLabel(category, l),
        limit: category.monthlyLimitCents,
        before: others + (wasHere ? old.amountCents : 0),
        after: others + cents,
      );
      await _db.saveExpense(ExpensesCompanion(
        id: _existing == null ? const Value.absent() : Value(_existing!.id),
        amountCents: Value(cents),
        date: Value(day),
        merchant: Value(merchant),
        categoryId: Value(_categoryId!),
        accountId: Value(_accountId!),
        note: Value(_note.text.trim()),
        receiptPath: Value(receiptPath),
        ocrText: Value(_existing?.ocrText ?? widget.draft?.ocrText),
      ));
      // La prossima volta questo esercente avrà subito la categoria giusta.
      await _db.learnMerchant(merchantKey(merchant), _categoryId!);
      await _db.setSetting('last_account', '$_accountId');
      if (!mounted) return;
      // Mostra il mese in cui è finita la spesa (uno scontrino vecchio
      // altrimenti "sparirebbe" dal mese corrente).
      final services = AppServices.of(context);
      final month = monthOf(_date);
      final moved = services.month.value != month;
      services.month.value = month;
      final saved = _existing != null ? l.expenseUpdated : (moved ? l.expenseSavedIn(month) : l.expenseSaved);
      if (alert != null && alert.crossed && alert.level == BudgetLevel.reached) {
        await showBudgetReachedDialog(context, alert);
        if (!mounted) return;
      }
      final note = alert == null || (alert.crossed && alert.level == BudgetLevel.reached) ? null : budgetNote(context, alert);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(note == null ? saved : '$saved. $note'),
        duration: Duration(seconds: note == null ? 4 : 6),
      ));
      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteExpenseTitle),
        content: Text(l.deleteExpenseMessage),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.delete)),
        ],
      ),
    );
    if (ok != true || _existing == null) return;
    await _db.deleteExpense(_existing!.id);
    final path = _existing!.receiptPath;
    if (path != null) {
      final f = File(path);
      if (await f.exists()) await f.delete();
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _amount.dispose();
    _merchant.dispose();
    _note.dispose();
    _merchantFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final draft = widget.draft;
    final l = context.l10n;
    final title = _existing != null ? l.editExpense : (draft != null ? l.checkReceipt : l.newExpense);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (_existing != null)
            IconButton(tooltip: l.delete, icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (draft != null || _existing?.receiptPath != null)
                    _ReceiptPreview(
                      bytes: draft?.imageBytes,
                      path: _existing?.receiptPath,
                      ocrText: draft?.ocrText ?? _existing?.ocrText,
                      warnings: draft?.warnings ?? const [],
                    ),
                  if (draft != null || _existing?.receiptPath != null) const SizedBox(height: 16),
                  TextFormField(
                    controller: _amount,
                    autofocus: draft == null && _existing == null,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: text.headlineMedium,
                    decoration: InputDecoration(labelText: l.amount, prefixText: '€ '),
                    validator: (v) {
                      final c = parseCents(v ?? '');
                      if (c == null || c == 0) return l.enterAmount;
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  RawAutocomplete<String>(
                    textEditingController: _merchant,
                    focusNode: _merchantFocus,
                    optionsBuilder: (v) {
                      final q = v.text.toLowerCase();
                      if (q.isEmpty) return const Iterable<String>.empty();
                      return _merchants.where((m) => m.toLowerCase().contains(q) && m.toLowerCase() != q).take(6);
                    },
                    onSelected: (_) => _resuggestCategory(),
                    fieldViewBuilder: (context, controller, focus, onSubmit) => TextFormField(
                      controller: controller,
                      focusNode: focus,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(labelText: l.merchant, hintText: l.merchantHint),
                      onFieldSubmitted: (_) => onSubmit(),
                    ),
                    optionsViewBuilder: (context, onSelected, options) => Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(12),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: 240, maxWidth: MediaQuery.sizeOf(context).width - 32),
                          child: ListView(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            children: [
                              for (final o in options) ListTile(title: Text(o), onTap: () => onSelected(o)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(l.category, style: text.titleSmall),
                  if (_categoryReason != null && !_categoryTouched)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(_categoryReason!, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in _categories)
                        ChoiceChip(
                          avatar: Icon(iconOf(c), size: 18, color: Color(c.color)),
                          label: Text(categoryLabel(c, l)),
                          selected: _categoryId == c.id,
                          onSelected: (_) => setState(() {
                            _categoryId = c.id;
                            _categoryTouched = true;
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(l.paidWith, style: text.titleSmall),
                  const SizedBox(height: 8),
                  StreamBuilder<List<Account>>(
                    stream: _db.watchAccounts(),
                    builder: (context, snap) {
                      final accounts = snap.data ?? const <Account>[];
                      if (accounts.isEmpty) return const SizedBox(height: 40);
                      return SegmentedButton<int>(
                        segments: [
                          for (final a in accounts)
                            ButtonSegment(value: a.id, label: Text(accountLabel(a, l)), icon: Icon(accountIcon(a.kind))),
                        ],
                        selected: {?_accountId},
                        emptySelectionAllowed: true,
                        showSelectedIcon: false,
                        onSelectionChanged: (s) => setState(() => _accountId = s.isEmpty ? _accountId : s.first),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: Text(formatDay(context, _date)),
                    subtitle: draft != null && draft.date == null
                        ? Text(l.dateNotFound, style: TextStyle(color: scheme.error))
                        : null,
                    trailing: const Icon(Icons.edit_calendar_outlined),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (d != null) setState(() => _date = d);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _note,
                    decoration: InputDecoration(labelText: l.noteOptional),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.check),
                    label: Text(l.save),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  ),
                ],
              ),
            ),
    );
  }
}

String describeSuggestion(CategorySuggestion s, AppLocalizations l, {bool fromReceipt = true}) => switch (s.source) {
      SuggestionSource.learned => l.suggestedLearned,
      SuggestionSource.keyword => fromReceipt
          ? l.suggestedKeywordReceipt('${s.matched?.toLowerCase()}')
          : l.suggestedKeyword('${s.matched?.toLowerCase()}'),
      SuggestionSource.none => '',
    };

class _ReceiptPreview extends StatefulWidget {
  final Uint8List? bytes;
  final String? path;
  final String? ocrText;
  final List<String> warnings;
  const _ReceiptPreview({this.bytes, this.path, this.ocrText, this.warnings = const []});

  @override
  State<_ReceiptPreview> createState() => _ReceiptPreviewState();
}

class _ReceiptPreviewState extends State<_ReceiptPreview> {
  bool _showText = false;

  ImageProvider? get _image {
    if (widget.bytes != null) return MemoryImage(widget.bytes!);
    if (widget.path != null && File(widget.path!).existsSync()) return FileImage(File(widget.path!));
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final image = _image;
    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (image != null)
            InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: Text(context.l10n.receiptTitle)),
                    body: InteractiveViewer(maxScale: 6, child: Center(child: Image(image: image))),
                  ),
                ),
              ),
              child: SizedBox(height: 180, child: Image(image: image, fit: BoxFit.cover, alignment: Alignment.topCenter)),
            ),
          for (final w in widget.warnings)
            Container(
              color: scheme.tertiaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: scheme.onTertiaryContainer),
                  const SizedBox(width: 8),
                  Expanded(child: Text(w, style: TextStyle(color: scheme.onTertiaryContainer))),
                ],
              ),
            ),
          if (widget.ocrText != null && widget.ocrText!.isNotEmpty) ...[
            ListTile(
              dense: true,
              title: Text(context.l10n.receiptText),
              trailing: Icon(_showText ? Icons.expand_less : Icons.expand_more),
              onTap: () => setState(() => _showText = !_showText),
            ),
            if (_showText)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SelectableText(widget.ocrText!, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              ),
          ],
        ],
      ),
    );
  }
}

/// Testo breve per gli avvisi meno gravi (80% o limite già superato).
String budgetNote(BuildContext context, BudgetAlert a) {
  final l = context.l10n;
  return switch (a.level) {
    BudgetLevel.near => l.budgetNear(a.category, (a.spent * 100 / a.limit).floor(), formatCents(context, a.left)),
    BudgetLevel.reached =>
      a.over == 0 ? l.budgetExhausted(a.category) : l.budgetOver(a.category, formatCents(context, a.over)),
    BudgetLevel.ok => '',
  };
}

Future<void> showBudgetReachedDialog(BuildContext context, BudgetAlert a) {
  final scheme = Theme.of(context).colorScheme;
  final l = context.l10n;
  String money(int cents) => formatCents(context, cents);
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(Icons.warning_amber_rounded, color: scheme.error, size: 36),
      title: Text(l.budgetReachedTitle(a.category)),
      content: Text(a.over == 0
          ? l.budgetReachedExact(money(a.limit))
          : l.budgetReachedOver(money(a.spent), money(a.limit), money(a.over))),
      actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(l.gotIt))],
    ),
  );
}
