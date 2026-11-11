import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_app/ui/licenses.dart';

/// NOTICES è letto da Flutter (license_collector.dart) al posto di LICENSE:
/// voci separate da una riga di 80 trattini, ognuna con i nomi da mostrare,
/// una riga vuota e il testo. Se il formato si rompe, nell'app comparirebbe
/// tutto sotto una sola voce "receipt_app".
void main() {
  test('NOTICES ha le voci attese, nel formato che Flutter legge', () {
    final raw = File('NOTICES').readAsStringSync().split('\n${'-' * 80}\n');
    final entries = <String, String>{};
    for (final chunk in raw) {
      final split = chunk.indexOf('\n\n');
      expect(split, greaterThan(0));
      for (final name in chunk.substring(0, split).split('\n')) {
        entries[name] = chunk.substring(split + 2);
      }
    }

    expect(entries.keys, unorderedEquals(['Receipt', 'RapidOCR', 'PP-OCRv4', 'Clipper', 'ONNX Runtime', 'SQLite3MultipleCiphers']));
    final gpl = File('LICENSE').readAsStringSync().trim();
    expect(entries['Receipt'], allOf(startsWith(receiptCopyright), contains(receiptSource), contains(gpl)));
    for (final p in ['RapidOCR', 'PP-OCRv4']) {
      expect(entries[p], allOf(contains('PaddlePaddle Authors'), contains('Apache License')));
    }
    expect(entries['Clipper'], allOf(contains('Angus Johnson'), contains('Boost Software License')));
    expect(entries['ONNX Runtime'], allOf(contains('Microsoft Corporation'), contains('Permission is hereby granted')));
    expect(entries['SQLite3MultipleCiphers'], allOf(contains('Ulrich Telle'), contains('Permission is hereby granted')));
  });
}
