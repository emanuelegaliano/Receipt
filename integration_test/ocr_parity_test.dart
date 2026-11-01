import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:receipt_app/ocr/rapid_ocr.dart';

/// Esegue RapidOCR Dart su immagini servite dal Mac e stampa i risultati come
/// righe `OCR_RESULT {json}`, da confrontare con tools/rapidocr_reference.py.
///
/// Sul Mac, nella cartella delle immagini:
///   python3 -m http.server 8765
///   adb reverse tcp:8765 tcp:8765
/// poi:
///   flutter test integration_test/ocr_parity_test.dart \
///     --dart-define=SAMPLES=img1.jpg,img2.jpg
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const samples = String.fromEnvironment('SAMPLES');
  const host = String.fromEnvironment('SAMPLES_HOST', defaultValue: 'http://127.0.0.1:8765');

  testWidgets('OCR sugli scontrini di esempio', (tester) async {
    final names = samples.split(',').where((s) => s.isNotEmpty).toList();
    expect(names, isNotEmpty, reason: 'passa --dart-define=SAMPLES=a.jpg,b.jpg');

    final engine = await RapidOcr.load();
    final client = HttpClient();
    for (final name in names) {
      final req = await client.getUrl(Uri.parse('$host/$name'));
      final res = await req.close();
      final bytes = await consolidateHttpClientResponseBytes(res);
      final r = await engine.recognize(bytes);
      // ignore: avoid_print
      print('OCR_RESULT ${jsonEncode({
            'image': name,
            'timings': r.timingsMs,
            'lines': [
              for (final l in r.lines)
                {
                  'box': [for (final p in l.box) [p.x, p.y]],
                  'text': l.text,
                  'score': l.score,
                }
            ],
          })}');
    }
    client.close();
    await engine.close();
  });
}
