import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:receipt_app/receipt/receipt_scanner.dart';

/// Benchmark end-to-end sul dataset SROIE: OCR + parser Dart sull'emulatore.
///
/// Sul Mac, nella cartella dello split (quella con img/ ed entities/):
///   python3 -m http.server 8765 --bind 127.0.0.1
///   adb reverse tcp:8765 tcp:8765
///   flutter test integration_test/sroie_benchmark_test.dart [--dart-define=LIMIT=50] [--dart-define=LANG=it]
/// Stampa una riga `SROIE_RESULT {json}` per scontrino e `SROIE_SUMMARY` alla fine.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const host = String.fromEnvironment('SAMPLES_HOST', defaultValue: 'http://127.0.0.1:8765');
  const limit = int.fromEnvironment('LIMIT', defaultValue: 0);
  const lang = String.fromEnvironment('LANG', defaultValue: 'en');

  testWidgets('SROIE end-to-end', timeout: const Timeout(Duration(hours: 2)), (tester) async {
    final client = HttpClient();
    Future<List<int>> get(String path) async {
      final res = await (await client.getUrl(Uri.parse('$host/$path'))).close();
      return consolidateHttpClientResponseBytes(res);
    }

    final listing = utf8.decode(await get('img/'));
    var names = RegExp(r'href="([^"]+\.jpg)"').allMatches(listing).map((m) => Uri.decodeComponent(m[1]!)).toList()
      ..sort();
    if (limit > 0) names = names.take(limit).toList();
    expect(names, isNotEmpty);

    final scanner = await ReceiptScanner.load();
    var okTotal = 0, okDate = 0, okCompany = 0, okDateParsed = 0, ms = 0;
    for (final name in names) {
      final gt = jsonDecode(utf8.decode(await get('entities/${name.replaceAll('.jpg', '.txt')}'), allowMalformed: true));
      final gtTotal = double.tryParse('${gt['total'] ?? '0'}'.replaceAll(RegExp(r'[,$]|RM'), '').trim()) ?? 0;
      final gtDate = '${gt['date'] ?? ''}'.trim();
      final gtCompany = '${gt['company'] ?? ''}'.trim();

      final sw = Stopwatch()..start();
      final r = await scanner.scan(Uint8List.fromList(await get('img/$name')), lang: lang);
      ms += sw.elapsedMilliseconds;

      String digits(String s) => s.replaceAll(RegExp(r'[^\d]'), '');
      String norm(String s) => s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
      final tOk = gtTotal <= 0 || (r.parsed.total - gtTotal).abs() < 0.01;
      final dOk = gtDate.isEmpty || (digits(r.parsed.date).isNotEmpty ? digits(r.parsed.date) == digits(gtDate) : r.parsed.date == gtDate);
      final cOk = norm(r.parsed.company) == norm(gtCompany);
      okTotal += tOk ? 1 : 0;
      okDate += dOk ? 1 : 0;
      okCompany += cOk ? 1 : 0;
      okDateParsed += r.date != null ? 1 : 0;
      // ignore: avoid_print
      print('SROIE_RESULT ${jsonEncode({
            'image': name,
            'ms': sw.elapsedMilliseconds,
            'pred': {'company': r.parsed.company, 'date': r.parsed.date, 'total': r.parsed.total},
            'iso': r.date?.toIso8601String(),
            'ok': {'total': tOk, 'date': dOk, 'company': cOk},
          })}');
    }
    String pct(int v) => (100 * v / names.length).toStringAsFixed(1);
    // ignore: avoid_print
    print('SROIE_SUMMARY n=${names.length} totale=${pct(okTotal)}% data=${pct(okDate)}% '
        'esercente=${pct(okCompany)}% data_convertita=${pct(okDateParsed)}% media=${ms ~/ names.length}ms');
    client.close();
  });
}
