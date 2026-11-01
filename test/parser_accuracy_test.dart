import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_app/ocr/geometry.dart';
import 'package:receipt_app/ocr/ocr_pipeline.dart';
import 'package:receipt_app/receipt/receipt_parser.dart';
import 'package:receipt_app/receipt/receipt_scanner.dart';

/// Accuratezza del parser con le correzioni dell'app (raddrizzamento e
/// esclusioni a parola intera) rispetto a PyReceipt, sugli stessi output OCR.
/// Fixture generate con tools/sroie_baseline.py + tools/make_parser_fixture.py.
({double total, double date, double company, double pyTotal, double pyDate, double pyCompany}) _evaluate(
    String fixture, String lang) {
  final data =
      jsonDecode(utf8.decode(gzip.decode(File(fixture).readAsBytesSync()))) as Map<String, dynamic>;
  final parser = Spatial2DParser(LangConfig.fromJson(jsonDecode(File('assets/parser/$lang.json').readAsStringSync())));

  String digits(String s) => s.replaceAll(RegExp(r'[^\d]'), '');
  String norm(String s) => s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  var t = 0, d = 0, c = 0, pt = 0, pd = 0, pc = 0;
  final failures = <String>[];
  data.forEach((name, v) {
    final lines = [
      for (final b in v['boxes'] as List)
        OcrLine(
          [for (final p in b['poly'] as List) Point2((p[0] as num).toDouble(), (p[1] as num).toDouble())],
          b['text'] as String,
          (b['conf'] as num).toDouble(),
        ),
    ];
    final r = parser.parse(ReceiptScanner.toBoxes(lines));
    final gt = v['gt'] as Map<String, dynamic>;
    final py = v['pred'] as Map<String, dynamic>;
    final gtTotal = (gt['total'] as num).toDouble();
    bool totalOk(double x) => gtTotal <= 0 || (x - gtTotal).abs() < 0.01;
    bool dateOk(String x) => (gt['date'] as String).isEmpty || digits(x) == digits(gt['date']);
    bool companyOk(String x) => norm(x) == norm(gt['company']);
    if (totalOk(r.total)) t++;
    if (dateOk(r.date)) d++;
    if (companyOk(r.company)) c++;
    if (totalOk((py['total'] as num).toDouble())) pt++;
    if (dateOk(py['date'])) pd++;
    if (companyOk(py['company'])) pc++;
    if (!totalOk(r.total) && totalOk((py['total'] as num).toDouble())) {
      failures.add('$name peggiorato: dart ${r.total} py ${py['total']} gt $gtTotal');
    }
  });
  final n = data.length;
  double pct(int x) => 100 * x / n;
  // ignore: avoid_print
  print('$fixture (n=$n)\n'
      '  app      : totale ${pct(t).toStringAsFixed(1)}%  data ${pct(d).toStringAsFixed(1)}%  esercente ${pct(c).toStringAsFixed(1)}%\n'
      '  PyReceipt: totale ${pct(pt).toStringAsFixed(1)}%  data ${pct(pd).toStringAsFixed(1)}%  esercente ${pct(pc).toStringAsFixed(1)}%\n'
      '${failures.take(8).map((f) => '  $f').join('\n')}');
  return (total: pct(t), date: pct(d), company: pct(c), pyTotal: pct(pt), pyDate: pct(pd), pyCompany: pct(pc));
}

void main() {
  for (final (fixture, lang) in [
    ('test/fixtures/italian_parser.json.gz', 'it'),
    ('test/fixtures/sroie_parser.json.gz', 'en'),
  ]) {
    test('le correzioni non peggiorano PyReceipt: $fixture', () {
      if (!File(fixture).existsSync()) return;
      final r = _evaluate(fixture, lang);
      expect(r.total, greaterThanOrEqualTo(r.pyTotal));
      expect(r.date, greaterThanOrEqualTo(r.pyDate));
      expect(r.company, greaterThanOrEqualTo(r.pyCompany));
    });
  }
}
