import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_app/receipt/receipt_parser.dart';

/// Scontrini veri che hanno dato problemi, ridotti al testo letto dall'OCR
/// e a una posizione approssimata delle righe.
void main() {
  final parser = Spatial2DParser(LangConfig.fromJson(jsonDecode(File('assets/parser/it.json').readAsStringSync())));

  List<OcrBox> boxes(List<(String, int, int)> rows) =>
      [for (final (t, x, y) in rows) OcrBox(t, [x, y, x + t.length * 18, y + 30], 0.9)];

  test('insegna e titolare: "CASH TIME / DI SHADA SAS" dà l\'insegna', () {
    final r = parser.parse(boxes([
      ('CASH TIME', 240, 40), ('DI SHADA SAS', 220, 80), ('VIA SACCHI 40/D', 190, 115),
      ('10128 TORINO', 225, 150), ('TEL366.311.3126', 170, 190), ('P.IVA 10359580015', 165, 230),
      ('DOCUMENTO COMMERCIALE', 120, 300), ('DESCRIZIONE', 20, 420), ('IVA Prezzo(E)', 350, 420),
      ('REP02', 20, 500), ('RM#', 340, 500), ('6,90', 560, 500),
      ('TOTALE COMPLESSIVO', 20, 570), ('6,90', 560, 570), ('di cui IVA', 20, 640), ('D,00', 560, 640),
      ('Pagamento contante', 20, 700), ('6,90', 560, 700), ('Importo pagato', 20, 735), ('6,90', 560, 735),
      ('28-10-202613:13', 140, 860), ('DOCUMENTO N. 2082-0004', 100, 895),
    ]));
    expect((r.company, r.date, r.total), ('CASH TIME', '28-10-2026', 6.9));
  });

  test('senza insegna sopra resta la ragione sociale', () {
    final r = parser.parse(boxes([
      ('ESSELUNGA S.P.A.', 200, 40), ('Viale Monza 25 - Milano', 150, 80),
      ('TOTALE COMPLESSIVO', 20, 300), ('7,46', 560, 300),
    ]));
    expect(r.company, 'ESSELUNGA S.P.A.');
  });
}
