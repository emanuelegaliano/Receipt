import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_app/receipt/receipt_parser.dart';

/// Il parser Dart deve dare gli stessi risultati di Spatial2DBoxParser
/// (PyReceipt) sugli stessi box OCR dei 347 scontrini di test SROIE.
/// Fixture generata da tools/sroie_baseline.py.
void main() {
  test('parità con PyReceipt su SROIE', () {
    final data = jsonDecode(utf8.decode(gzip.decode(File('test/fixtures/sroie_parser.json.gz').readAsBytesSync())))
        as Map<String, dynamic>;
    final parser = Spatial2DParser(LangConfig.fromJson(jsonDecode(File("assets/parser/en.json").readAsStringSync())), strict: true);

    var same = 0;
    final diffs = <String>[];
    data.forEach((name, v) {
      final boxes = [for (final b in v['boxes'] as List) OcrBox.fromJson(b as Map<String, dynamic>)];
      final r = parser.parse(boxes);
      final p = v['pred'] as Map<String, dynamic>;
      final ok = r.company == p['company'] && r.date == p['date'] && (r.total - (p['total'] as num)).abs() < 1e-9;
      if (ok) {
        same++;
      } else if (diffs.length < 10) {
        diffs.add('$name\n  py  : ${p['company']} | ${p['date']} | ${p['total']}\n  dart: ${r.company} | ${r.date} | ${r.total}');
      }
    });
    // ignore: avoid_print
    print('identici a Python: $same/${data.length}\n${diffs.join('\n')}');
    expect(same, data.length);
  });
}
