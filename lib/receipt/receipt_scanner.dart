import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../ocr/ocr_pipeline.dart';
import '../ocr/rapid_ocr.dart';
import 'date_normalizer.dart';
import 'receipt_parser.dart';

/// Cosa siamo riusciti a capire da una foto di scontrino.
class ScanResult {
  final OcrResult ocr;
  final ParsedReceipt parsed;
  final DateTime? date;
  const ScanResult(this.ocr, this.parsed, this.date);

  bool get hasTotal => parsed.total > 0;
}

/// OCR (RapidOCR) + parser (porta di PyReceipt) con la lingua scelta.
class ReceiptScanner {
  final RapidOcr _ocr;
  final Map<String, Spatial2DParser> _parsers;

  ReceiptScanner._(this._ocr, this._parsers);

  static Future<ReceiptScanner> load() async {
    final ocr = await RapidOcr.load();
    final parsers = <String, Spatial2DParser>{};
    for (final lang in ['it', 'en']) {
      final json = jsonDecode(await rootBundle.loadString('assets/parser/$lang.json'));
      parsers[lang] = Spatial2DParser(LangConfig.fromJson(json));
    }
    await ocr.warmUp();
    return ReceiptScanner._(ocr, parsers);
  }

  /// Inclinazione del testo in radianti: mediana dell'angolo del lato
  /// superiore delle righe larghe (quelle corte danno angoli poco affidabili).
  static double estimateSkew(List<OcrLine> lines) {
    final angles = <double>[];
    for (final l in lines) {
      final b = l.box;
      final dx = b[1].x - b[0].x, dy = b[1].y - b[0].y;
      final h = b[0].distanceTo(b[3]);
      if (dx > 0 && dx > 3 * h) angles.add(math.atan2(dy, dx));
    }
    if (angles.length < 3) return 0;
    angles.sort();
    return angles[angles.length ~/ 2];
  }

  /// Righe OCR nel formato del parser. Con [deskew] le coordinate vengono
  /// prima ruotate per annullare l'inclinazione della foto: PyReceipt
  /// raggruppa le righe per altezza e, con lo scontrino storto di 2-3°, i
  /// prezzi a destra finirebbero agganciati alla riga sotto.
  static List<OcrBox> toBoxes(List<OcrLine> lines, {bool deskew = true}) {
    final angle = deskew ? estimateSkew(lines) : 0.0;
    final rotate = angle.abs() > 0.3 * math.pi / 180;
    final c = math.cos(-angle), s = math.sin(-angle);
    final boxes = <OcrBox>[];
    for (final l in lines) {
      if (l.text.trim().isEmpty) continue;
      if (!rotate) {
        final b = l.toPyReceiptBox();
        boxes.add(OcrBox(b.text.trim(), b.box, b.conf));
        continue;
      }
      final xs = [for (final p in l.box) p.x * c - p.y * s];
      final ys = [for (final p in l.box) p.x * s + p.y * c];
      boxes.add(OcrBox(l.text.trim(), [
        xs.reduce(math.min).round(),
        ys.reduce(math.min).round(),
        xs.reduce(math.max).round(),
        ys.reduce(math.max).round(),
      ], l.score));
    }
    boxes.sort((a, b) => a.box[1] != b.box[1] ? a.box[1].compareTo(b.box[1]) : a.box[0].compareTo(b.box[0]));
    return boxes;
  }

  Future<ScanResult> scan(Uint8List imageBytes, {String lang = 'it'}) async {
    final ocr = await _ocr.recognize(imageBytes);
    final parsed = (_parsers[lang] ?? _parsers['it']!).parse(toBoxes(ocr.lines));
    return ScanResult(ocr, parsed, normalizeReceiptDate(parsed.date));
  }
}
