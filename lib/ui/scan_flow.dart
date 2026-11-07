import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../app_services.dart';
import '../receipt/categorizer.dart';
import '../receipt/payment_detector.dart';
import 'expense_form_screen.dart';
import 'l10n.dart';

/// Scatta o sceglie una foto e apre la schermata di lettura.
Future<void> startScan(BuildContext context, {required bool fromCamera}) async {
  // Fotocamera e galleria mandano l'app in sottofondo: niente blocco al ritorno.
  final file = await AppServices.of(context).lock.whileAway(() => ImagePicker().pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        // RapidOCR lavora al massimo a 2000 px: oltre si perde solo tempo.
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 92,
      ));
  if (file == null || !context.mounted) return;
  final bytes = await _readAndDelete(file);
  if (!context.mounted) return;
  await Navigator.push(context, MaterialPageRoute(builder: (_) => ScanProcessingScreen(bytes)));
}

/// image_picker lascia nella cache copie in chiaro della foto (l'originale
/// in una cartella con un UUID per nome, quella ridotta come scaled_*): si
/// legge la foto e si cancellano subito, anche quelle rimaste da prima.
/// Quella da tenere si salva cifrata (vedi ReceiptPhotos).
Future<Uint8List> _readAndDelete(XFile file) async {
  final bytes = await file.readAsBytes();
  try {
    await deletePickerCopies(await getTemporaryDirectory());
  } on FileSystemException {
    // Riprova alla prossima foto.
  }
  return bytes;
}

final _uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');

/// Cancella da [cache] i file lasciati da image_picker (con [olderThan], solo
/// quelli più vecchi). Non tocca il resto (modelli OCR, aggiornamenti,
/// esportazioni).
Future<void> deletePickerCopies(Directory cache, {Duration? olderThan}) async {
  final limit = olderThan == null ? null : DateTime.now().subtract(olderThan);
  await for (final e in cache.list()) {
    final name = p.basename(e.path);
    if (limit != null && (await e.stat()).modified.isAfter(limit)) continue;
    if (e is Directory && _uuid.hasMatch(name)) {
      await e.delete(recursive: true);
    } else if (e is File && (name.startsWith('scaled_') || name.startsWith('image_picker'))) {
      await e.delete();
    }
  }
}

/// Se Android ha chiuso Receipt mentre la fotocamera era aperta (succede
/// quando manca memoria), la foto non è persa: image_picker la tiene da parte
/// e la restituisce al riavvio. Va chiamata all'apertura dell'app.
Future<void> recoverLostScan(BuildContext context) async {
  final LostDataResponse lost;
  try {
    lost = await ImagePicker().retrieveLostData();
  } catch (_) {
    return;
  }
  final file = lost.file;
  if (lost.isEmpty || file == null || !context.mounted) return;
  final bytes = await _readAndDelete(file);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.scanRecovered)));
  await Navigator.push(context, MaterialPageRoute(builder: (_) => ScanProcessingScreen(bytes)));
}

class ScanProcessingScreen extends StatefulWidget {
  final Uint8List bytes;
  const ScanProcessingScreen(this.bytes, {super.key});

  @override
  State<ScanProcessingScreen> createState() => _ScanProcessingScreenState();
}

class _ScanProcessingScreenState extends State<ScanProcessingScreen> {
  bool _reading = false;
  String? _error;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _run();
  }

  Future<void> _run() async {
    final services = AppServices.of(context);
    final l = context.l10n;
    try {
      final scanner = await services.scanner();
      if (!mounted) return;
      setState(() => _reading = true);
      final lang = await services.db.setting('receipt_lang') ?? 'it';
      final result = await scanner.scan(widget.bytes, lang: lang);
      debugPrint('Scansione: ${result.ocr.lines.length} righe, tempi ${result.ocr.timingsMs}');

      final db = services.db;
      final categories = await db.allCategories();
      final rules = await db.loadMerchantRules();
      final accounts = await db.watchAccounts().first;
      final merchant = displayMerchant(result.parsed.company);
      final suggestion = suggestCategory(
        merchant: merchant,
        ocrText: result.ocr.text,
        rules: rules,
        categories: [for (final c in categories) CategoryKeywords.parse(c.id, c.keywords)],
      );
      final kind = detectPaymentKind(result.ocr.text);
      final account = kind == null ? null : accounts.where((a) => a.kind == kind).firstOrNull;

      final warnings = <String>[
        if (result.ocr.lines.isEmpty) l.scanWarnNoText,
        if (result.ocr.lines.isNotEmpty && !result.hasTotal) l.scanWarnNoTotal,
        if (result.ocr.lines.isNotEmpty && merchant.isEmpty) l.scanWarnNoMerchant,
      ];

      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ExpenseFormScreen(
            draft: ScanDraft(
              imageBytes: widget.bytes,
              amountCents: result.hasTotal ? (result.parsed.total * 100).round() : null,
              date: result.date,
              merchant: merchant,
              ocrText: result.ocr.text,
              categoryId: suggestion.categoryId ?? categories.where((c) => c.name == 'Altro').firstOrNull?.id,
              categoryReason: suggestion.categoryId == null ? null : describeSuggestion(suggestion, l),
              accountId: account?.id,
              warnings: warnings,
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.receiptTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(widget.bytes, fit: BoxFit.contain, cacheHeight: 1200),
              ),
            ),
            const SizedBox(height: 24),
            if (_error == null) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
              Text(_reading ? l.scanReading : l.scanPreparing, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(l.scanOffline, style: TextStyle(color: scheme.onSurfaceVariant)),
            ] else ...[
              Text(l.scanFailed, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(_error!, style: TextStyle(color: scheme.error), maxLines: 4, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const ExpenseFormScreen()),
                ),
                child: Text(l.addManualTitle),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
