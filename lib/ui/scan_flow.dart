import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_services.dart';
import '../receipt/categorizer.dart';
import '../receipt/payment_detector.dart';
import 'expense_form_screen.dart';

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
  final bytes = await file.readAsBytes();
  if (!context.mounted) return;
  await Navigator.push(context, MaterialPageRoute(builder: (_) => ScanProcessingScreen(bytes)));
}

class ScanProcessingScreen extends StatefulWidget {
  final Uint8List bytes;
  const ScanProcessingScreen(this.bytes, {super.key});

  @override
  State<ScanProcessingScreen> createState() => _ScanProcessingScreenState();
}

class _ScanProcessingScreenState extends State<ScanProcessingScreen> {
  String _status = 'Preparo il lettore…';
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
    try {
      final scanner = await services.scanner();
      if (!mounted) return;
      setState(() => _status = 'Leggo lo scontrino…');
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
        if (result.ocr.lines.isEmpty) 'Non ho trovato testo: prova con una foto più nitida e dritta.',
        if (result.ocr.lines.isNotEmpty && !result.hasTotal) 'Totale non trovato: inseriscilo a mano.',
        if (result.ocr.lines.isNotEmpty && merchant.isEmpty) 'Esercente non trovato.',
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
              categoryReason: suggestion.categoryId == null ? null : describeSuggestion(suggestion),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Scontrino')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(widget.bytes, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 24),
            if (_error == null) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
              Text(_status, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('Tutto avviene sul telefono, senza connessione.',
                  style: TextStyle(color: scheme.onSurfaceVariant)),
            ] else ...[
              Text('Non sono riuscito a leggere lo scontrino', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(_error!, style: TextStyle(color: scheme.error), maxLines: 4, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const ExpenseFormScreen()),
                ),
                child: const Text('Inserisci a mano'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
